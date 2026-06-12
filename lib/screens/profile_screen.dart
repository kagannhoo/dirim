import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../models/emergency_contact.dart';
import '../services/emergency_contact_service.dart';
import '../widgets/emergency_contact_editor.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _phoneController = TextEditingController();
  final _allergiesController = TextEditingController();
  List<EmergencyContact> _emergencyContacts = [];
  final _conditionsController = TextEditingController();

  String? _email;
  String? _selectedGender;
  String? _selectedBloodType;
  String _memberSince = '';
  int _totalReports = 0;
  String _lastAnalysisDate = '—';
  double? _bmi;

  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'];
  static const _genders = ['Erkek', 'Kadın', 'Diğer'];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      _email = user.email;
      _memberSince = _formatDate(user.createdAt);

      // users_profile tablosundan veri çek
      final response = await _supabase
          .from('users_profile')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        _fillFromProfile(response);
      } else {
        // Eski profiles tablosundan fallback
        try {
          final legacy = await _supabase
              .from('profiles')
              .select()
              .eq('auth_id', user.id)
              .maybeSingle();
          if (legacy != null) {
            _nameController.text = legacy['ad_soyad'] ?? '';
            _ageController.text = legacy['age']?.toString() ?? '';
            _selectedGender = legacy['gender'];
            _email = legacy['email'] ?? _email;
          }
        } catch (_) {}
      }

      // Sağlık istatistikleri
      final reports = await _supabase
          .from('health_history')
          .select('created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      _totalReports = (reports as List).length;
      if (_totalReports > 0) {
        _lastAnalysisDate = _formatDate(reports.first['created_at']);
      }

      _calculateBmi();
      _emergencyContacts = await EmergencyContactService.instance.fetchContacts();
    } catch (e) {
      debugPrint("Profil yüklenirken hata: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillFromProfile(Map<String, dynamic> data) {
    _nameController.text = data['full_name'] ?? '';
    _ageController.text = data['age']?.toString() ?? '';
    _heightController.text = data['height']?.toString() ?? '';
    _weightController.text = data['weight']?.toString() ?? '';
    _phoneController.text = data['phone'] ?? '';
    _allergiesController.text = data['allergies'] ?? '';
    _conditionsController.text = data['chronic_conditions'] ?? '';
    _selectedGender = data['gender'];
    _selectedBloodType = data['blood_type'];
    _email = data['email'] ?? _email;
  }

  void _calculateBmi() {
    final h = double.tryParse(_heightController.text);
    final w = double.tryParse(_weightController.text);
    if (h != null && w != null && h > 0) {
      _bmi = w / ((h / 100) * (h / 100));
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String get _bmiLabel {
    if (_bmi == null) return '—';
    if (_bmi! < 18.5) return 'Zayıf';
    if (_bmi! < 25) return 'Normal';
    if (_bmi! < 30) return 'Fazla Kilolu';
    return 'Obez';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("Kullanıcı girişi bulunamadı.");

      final profileData = {
        'user_id': user.id,
        'full_name': _nameController.text.trim(),
        'email': _email ?? user.email,
        'age': int.tryParse(_ageController.text.trim()),
        'gender': _selectedGender,
        'height': double.tryParse(_heightController.text.trim()),
        'weight': double.tryParse(_weightController.text.trim()),
        'blood_type': _selectedBloodType,
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'allergies': _allergiesController.text.trim().isEmpty
            ? null
            : _allergiesController.text.trim(),
        'chronic_conditions': _conditionsController.text.trim().isEmpty
            ? null
            : _conditionsController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('users_profile').upsert(profileData);
      _calculateBmi();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profil başarıyla güncellendi!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      debugPrint("Profil kaydedilirken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _phoneController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: const Text(
          "Hesap Bilgilerim",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountHeader(),
                    const SizedBox(height: 24),
                    _buildHealthStats(),
                    const SizedBox(height: 24),
                    _sectionTitle("Kişisel Bilgiler"),
                    const SizedBox(height: 12),
                    _buildTextField(_nameController, "Ad Soyad", Icons.person_outline, required: true),
                    const SizedBox(height: 12),
                    _buildReadOnlyField("E-posta", _email ?? '—', Icons.email_outlined),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(_ageController, "Yaş", Icons.cake_outlined, required: true, isNumber: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildGenderDropdown()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(_phoneController, "Telefon", Icons.phone_outlined, isNumber: true),
                    const SizedBox(height: 24),
                    _sectionTitle("Sağlık Bilgileri"),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_heightController, "Boy (cm)", Icons.height, isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(_weightController, "Kilo (kg)", Icons.monitor_weight_outlined, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildBloodTypeDropdown(),
                    if (_bmi != null) ...[
                      const SizedBox(height: 12),
                      _buildBmiCard(),
                    ],
                    const SizedBox(height: 12),
                    _buildTextField(_allergiesController, "Alerjiler", Icons.warning_amber_outlined, maxLines: 2),
                    const SizedBox(height: 12),
                    _buildTextField(_conditionsController, "Kronik Hastalıklar", Icons.medical_information_outlined, maxLines: 2),
                    const SizedBox(height: 24),
                    _buildEmergencyContactsSection(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isSaving ? null : _saveProfile,
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "Bilgileri Kaydet",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAccountHeader() {
    final initials = _nameController.text.isNotEmpty
        ? _nameController.text.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.isNotEmpty ? _nameController.text : 'Profilinizi tamamlayın',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDarkGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email ?? '',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Üyelik: $_memberSince',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStats() {
    return Row(
      children: [
        Expanded(child: _statCard('Analiz', '$_totalReports', Icons.analytics_outlined, AppColors.primaryBlue)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Son Analiz', _lastAnalysisDate, Icons.history, Colors.teal)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('BMI', _bmi?.toStringAsFixed(1) ?? '—', Icons.favorite_outline, Colors.orange)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDarkGrey),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildBmiCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_outlined, color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: 10),
          Text(
            'Vücut Kitle İndeksi: ${_bmi!.toStringAsFixed(1)} ($_bmiLabel)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDarkGrey),
          ),
        ],
      ),
    );
  }

  Future<void> _reloadEmergencyContacts() async {
    final contacts = await EmergencyContactService.instance.fetchContacts();
    if (mounted) setState(() => _emergencyContacts = contacts);
  }

  Future<void> _syncContactToRehber(EmergencyContact contact) async {
    final ok = await EmergencyContactService.instance.syncToRehber(contact);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? '${contact.name} telefon rehberine eklendi' : 'Rehber izni verilmedi veya ekleme başarısız',
        ),
        backgroundColor: ok ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) await _reloadEmergencyContacts();
  }

  Future<void> _deleteEmergencyContact(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kişiyi Sil'),
        content: Text('"${contact.name}" acil durum listesinden kaldırılsın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await EmergencyContactService.instance.deleteContact(contact.id);
    await _reloadEmergencyContacts();
  }

  Widget _buildEmergencyContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('Acil Durum Kişileri')),
            TextButton.icon(
              onPressed: () => EmergencyContactEditor.show(
                context,
                onSaved: _reloadEmergencyContacts,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Rehber izni verilen kişiler telefon rehberinize eklenir ve doğrudan aranır',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        if (_emergencyContacts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Henüz acil durum kişisi eklemediniz. Kişi eklerken rehber izni verin.',
                    style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          )
        else
          ..._emergencyContacts.map((c) => _buildEmergencyContactCard(c)),
      ],
    );
  }

  Widget _buildEmergencyContactCard(EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: contact.isVerified ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
          child: Text(
            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
          ),
        ),
        title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${contact.relationship ?? 'Yakın'} · ${contact.displayPhone}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contact.isVerified)
              Tooltip(
                message: 'Telefon rehberinde',
                child: Icon(Icons.contacts, color: Colors.green.shade600, size: 20),
              )
            else
              Tooltip(
                message: 'Rehbere eklenmedi',
                child: Icon(Icons.contacts_outlined, color: Colors.orange.shade600, size: 20),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'edit') {
                  EmergencyContactEditor.show(
                    context,
                    existing: contact,
                    onSaved: _reloadEmergencyContacts,
                  );
                } else if (v == 'rehber') {
                  _syncContactToRehber(contact);
                } else if (v == 'delete') {
                  _deleteEmergencyContact(contact);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                if (!contact.isVerified)
                  const PopupMenuItem(value: 'rehber', child: Text('Rehbere Ekle')),
                const PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDarkGrey),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      onChanged: (_) {
        if (label.contains('Boy') || label.contains('Kilo')) {
          _calculateBmi();
          setState(() {});
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryBlue),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? '$label gerekli' : null
          : null,
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryBlue),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: InputDecoration(
        labelText: "Cinsiyet",
        prefixIcon: const Icon(Icons.wc, color: AppColors.primaryBlue),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
      onChanged: (v) => setState(() => _selectedGender = v),
    );
  }

  Widget _buildBloodTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBloodType,
      decoration: InputDecoration(
        labelText: "Kan Grubu",
        prefixIcon: const Icon(Icons.bloodtype_outlined, color: AppColors.primaryBlue),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Belirtilmedi')),
        ..._bloodTypes.map((b) => DropdownMenuItem(value: b, child: Text(b))),
      ],
      onChanged: (v) => setState(() => _selectedBloodType = v),
    );
  }
}
