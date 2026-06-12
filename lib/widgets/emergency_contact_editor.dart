import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/colors.dart';
import '../models/emergency_contact.dart';
import '../services/emergency_contact_service.dart';

class EmergencyContactEditor extends StatefulWidget {
  final EmergencyContact? existing;
  final VoidCallback onSaved;

  const EmergencyContactEditor({super.key, this.existing, required this.onSaved});

  static Future<void> show(BuildContext context, {EmergencyContact? existing, required VoidCallback onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmergencyContactEditor(existing: existing, onSaved: onSaved),
    );
  }

  @override
  State<EmergencyContactEditor> createState() => _EmergencyContactEditorState();
}

class _EmergencyContactEditorState extends State<EmergencyContactEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String? _relationship;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _phoneCtrl.text = widget.existing!.displayPhone;
      _relationship = widget.existing!.relationship;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final saved = await EmergencyContactService.instance.saveContact(
        id: widget.existing?.id,
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        relationship: _relationship,
        syncRehber: true,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();

      final message = saved.isVerified
          ? (widget.existing != null
              ? 'Kişi güncellendi ve telefon rehberine eklendi'
              : 'Kişi eklendi ve telefon rehberine kaydedildi')
          : (widget.existing != null
              ? 'Kişi güncellendi. Rehber izni verirseniz arama daha hızlı olur.'
              : 'Kişi kaydedildi. Rehber izni vermediğiniz için telefon rehberine eklenemedi.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: saved.isVerified ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.existing != null ? 'Kişiyi Düzenle' : 'Acil Durum Kişisi Ekle',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDarkGrey,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.contacts_outlined, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kaydettiğinizde rehber izni istenir. Kişi telefon rehberinize eklenir ve tek dokunuşla aranabilir.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _dec('Ad Soyad', Icons.person_outline),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Ad gerekli' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _relationship,
                  decoration: _dec('Yakınlık', Icons.family_restroom_outlined),
                  items: kRelationshipOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _relationship = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-\(\)]'))],
                  decoration: _dec('Cep Telefonu', Icons.phone_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Telefon gerekli';
                    if (!EmergencyContact.isValidTurkishMobile(v)) {
                      return 'Geçerli numara girin (05XX XXX XX XX)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Kaydet ve Rehbere Ekle',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
