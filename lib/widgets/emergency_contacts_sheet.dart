import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/emergency_contact.dart';
import '../services/emergency_contact_service.dart';
import '../screens/profile_screen.dart';

class EmergencyContactsSheet extends StatefulWidget {
  const EmergencyContactsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EmergencyContactsSheet(),
    );
  }

  @override
  State<EmergencyContactsSheet> createState() => _EmergencyContactsSheetState();
}

class _EmergencyContactsSheetState extends State<EmergencyContactsSheet> {
  final _service = EmergencyContactService.instance;
  List<EmergencyContact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await _service.fetchContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    }
  }

  Future<void> _call(EmergencyContact contact) async {
    final ok = await _service.callContact(contact);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arama başlatılamadı. Telefon uygulamasını kontrol edin.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 48),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.emergency, color: Colors.red.shade700, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acil Durum Kişileri',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDarkGrey,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kişiyi seçin — arama hemen başlar',
                          style: TextStyle(fontSize: 13, color: AppColors.textLightGrey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              )
            else if (_contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.contact_emergency_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Kayıtlı acil durum kişiniz yok',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hesap Bilgilerim sayfasından acil durum kişisi ekleyin. Rehber izniyle tek dokunuşla arayabilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        },
                        icon: const Icon(Icons.person_add_outlined, color: Colors.white),
                        label: const Text(
                          'Hesap Bilgilerime Git',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final c = _contacts[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${c.relationship ?? 'Yakın'} · ${c.displayPhone}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () => _call(c),
                          icon: const Icon(Icons.call, size: 18, color: Colors.white),
                          label: const Text('Ara', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
