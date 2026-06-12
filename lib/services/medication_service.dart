import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medication.dart';

class MedicationService {
  MedicationService._();
  static final MedicationService instance = MedicationService._();

  final _supabase = Supabase.instance.client;

  Future<List<Medication>> fetchCatalog({String? category, String? search}) async {
    try {
      var query = _supabase.from('medications').select().order('category').order('medication_name');

      final response = await query;
      var list = (response as List)
          .map((e) => Medication.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      if (category != null && category.isNotEmpty) {
        list = list.where((m) => m.category == category).toList();
      }

      if (search != null && search.trim().isNotEmpty) {
        final q = search.toLowerCase();
        list = list.where((m) {
          return m.name.toLowerCase().contains(q) ||
              m.activeIngredient.toLowerCase().contains(q) ||
              m.targetCondition.toLowerCase().contains(q) ||
              m.category.toLowerCase().contains(q);
        }).toList();
      }

      return list;
    } catch (e) {
      debugPrint('İlaç kataloğu yüklenemedi: $e');
      return [];
    }
  }

  Future<List<String>> fetchCategories() async {
    final meds = await fetchCatalog();
    return meds.map((m) => m.category).toSet().toList()..sort();
  }

  Future<List<UserMedication>> fetchMyMedications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('user_medications')
          .select('*, medications(*)')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => UserMedication.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('İlaçlarım yüklenemedi: $e');
      return [];
    }
  }

  Future<bool> isInMyMedications(String medicationId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final res = await _supabase
        .from('user_medications')
        .select('id')
        .eq('user_id', user.id)
        .eq('medication_id', medicationId)
        .maybeSingle();

    return res != null;
  }

  Future<UserMedication> addToMyMedications({
    required String medicationId,
    String? customDosage,
    String? frequency,
    String? notes,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı');

    final inserted = await _supabase
        .from('user_medications')
        .upsert({
          'user_id': user.id,
          'medication_id': medicationId,
          'custom_dosage': customDosage,
          'frequency': frequency,
          'notes': notes,
          'is_active': true,
        }, onConflict: 'user_id,medication_id')
        .select('*, medications(*)')
        .single();

    return UserMedication.fromMap(Map<String, dynamic>.from(inserted));
  }

  Future<void> updateMyMedication({
    required String id,
    String? customDosage,
    String? frequency,
    String? notes,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('user_medications').update({
      'custom_dosage': customDosage,
      'frequency': frequency,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id).eq('user_id', user.id);
  }

  Future<void> removeFromMyMedications(String id) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('user_medications')
        .update({'is_active': false})
        .eq('id', id)
        .eq('user_id', user.id);
  }
}
