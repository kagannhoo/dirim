import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart' hide PermissionStatus;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_contact.dart';

class EmergencyContactService {
  EmergencyContactService._();
  static final EmergencyContactService instance = EmergencyContactService._();

  final _supabase = Supabase.instance.client;

  Future<List<EmergencyContact>> fetchContacts({bool verifiedOnly = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('emergency_contacts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      var contacts = (response as List)
          .map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      if (contacts.isEmpty) {
        contacts = await _migrateLegacyContact(user.id);
      }

      if (verifiedOnly) {
        contacts = contacts.where((c) => c.isVerified).toList();
      }

      return contacts;
    } catch (e) {
      debugPrint('Acil durum kişileri yüklenemedi: $e');
      return await _migrateLegacyContact(user.id);
    }
  }

  Future<List<EmergencyContact>> _migrateLegacyContact(String userId) async {
    try {
      final profile = await _supabase
          .from('users_profile')
          .select('emergency_contact_name, emergency_contact_phone')
          .eq('user_id', userId)
          .maybeSingle();

      if (profile == null) return [];

      final name = profile['emergency_contact_name']?.toString().trim() ?? '';
      final phone = profile['emergency_contact_phone']?.toString().trim() ?? '';

      if (name.isEmpty || phone.isEmpty) return [];
      if (!EmergencyContact.isValidTurkishMobile(phone)) return [];

      final normalized = EmergencyContact.normalizeForStorage(phone);
      final inserted = await _supabase
          .from('emergency_contacts')
          .insert({
            'user_id': userId,
            'name': name,
            'phone': normalized,
            'relationship': 'Diğer',
            'is_verified': false,
          })
          .select()
          .single();

      return [EmergencyContact.fromMap(Map<String, dynamic>.from(inserted))];
    } catch (e) {
      debugPrint('Eski acil durum verisi taşınamadı: $e');
      return [];
    }
  }

  Future<bool> _requestRehberPermission() async {
    final status = await FlutterContacts.permissions.request(PermissionType.readWrite);
    return status == PermissionStatus.granted || status == PermissionStatus.limited;
  }

  /// Kişiyi telefon rehberine ekler veya günceller.
  Future<bool> syncToRehber(EmergencyContact contact) async {
    if (!await _requestRehberPermission()) return false;

    final phone = EmergencyContact.normalizeForStorage(contact.phone);
    final nameParts = contact.name.trim().split(RegExp(r'\s+'));
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    try {
      final allContacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      Contact? existing;
      for (final c in allContacts) {
        for (final p in c.phones) {
          if (EmergencyContact.normalizeForStorage(p.number) == phone) {
            existing = c;
            break;
          }
        }
        if (existing != null) break;
      }

      final contactName = Name(
        first: firstName,
        last: lastName.isEmpty ? null : lastName,
      );

      if (existing != null) {
        await FlutterContacts.update(
          existing.copyWith(
            name: contactName,
            phones: [Phone(number: phone, isPrimary: true)],
          ),
        );
      } else {
        await FlutterContacts.create(
          Contact(
            name: contactName,
            phones: [Phone(number: phone, isPrimary: true)],
          ),
        );
      }

      await markSyncedToRehber(contact.id);
      return true;
    } catch (e) {
      debugPrint('Rehbere eklenemedi: $e');
      return false;
    }
  }

  Future<EmergencyContact> saveContact({
    String? id,
    required String name,
    required String phone,
    String? relationship,
    bool syncRehber = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı');

    final normalized = EmergencyContact.normalizeForStorage(phone);
    if (!EmergencyContact.isValidTurkishMobile(normalized)) {
      throw Exception('Geçerli bir cep telefonu girin (05XX XXX XX XX)');
    }

    EmergencyContact saved;

    final data = {
      'user_id': user.id,
      'name': name.trim(),
      'phone': normalized,
      'relationship': relationship,
      'is_verified': false,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (id != null) {
      final updated = await _supabase
          .from('emergency_contacts')
          .update(data)
          .eq('id', id)
          .eq('user_id', user.id)
          .select()
          .single();
      saved = EmergencyContact.fromMap(Map<String, dynamic>.from(updated));
    } else {
      final inserted = await _supabase
          .from('emergency_contacts')
          .insert(data)
          .select()
          .single();
      saved = EmergencyContact.fromMap(Map<String, dynamic>.from(inserted));
    }

    if (syncRehber && await syncToRehber(saved)) {
      saved = saved.copyWith(isVerified: true);
    }

    return saved;
  }

  Future<void> markSyncedToRehber(String id) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('emergency_contacts')
        .update({
          'is_verified': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', user.id);
  }

  Future<void> deleteContact(String id) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('emergency_contacts')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
  }

  /// Doğrudan arama başlatır (Android: anında arar, iOS: arama ekranını açar).
  Future<bool> callContact(EmergencyContact contact) async {
    final phone = EmergencyContact.normalizeForStorage(contact.phone);

    try {
      if (Platform.isAndroid) {
        final phonePermission = await Permission.phone.request();
        if (phonePermission.isGranted) {
          final result = await FlutterPhoneDirectCaller.callNumber(phone);
          if (result == true) return true;
        }
      }

      final dialUri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(dialUri)) {
        return launchUrl(dialUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Arama başlatılamadı: $e');
    }
    return false;
  }
}
