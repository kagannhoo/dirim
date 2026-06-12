import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../models/health_reminder.dart';
import '../models/medication.dart';
import '../services/reminder_notification_service.dart';
import '../widgets/medication_picker_sheet.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _supabase = Supabase.instance.client;
  List<HealthReminder> _reminders = [];
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  ReminderType? _filterType;

  final _notificationService = ReminderNotificationService.instance;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadReminders();
  }

  Future<void> _initNotifications() async {
    await _notificationService.requestPermissions();
    final enabled = await _notificationService.areNotificationsEnabled();
    if (mounted) setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _syncNotifications() async {
    await _notificationService.syncReminders(_reminders);
  }

  Future<void> _loadReminders() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('health_reminders')
          .select()
          .eq('user_id', user.id)
          .order('is_active', ascending: false)
          .order('scheduled_date', ascending: true);

      final loaded = (response as List)
          .map((e) => HealthReminder.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      setState(() {
        _reminders = loaded;
        _isLoading = false;
      });

      await _syncNotifications();
    } catch (e) {
      debugPrint('Hatırlatıcı yükleme hatası: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hatırlatıcılar yüklenemedi. Supabase tablosunu oluşturdunuz mu?',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<HealthReminder> get _filtered {
    if (_filterType == null) return _reminders;
    return _reminders.where((r) => r.type == _filterType).toList();
  }

  int get _activeCount => _reminders.where((r) => r.isActive).length;
  int get _upcomingCount => _reminders.where((r) => r.isUpcoming).length;

  Future<void> _toggleActive(HealthReminder reminder) async {
    try {
      await _supabase
          .from('health_reminders')
          .update({
            'is_active': !reminder.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reminder.id);
      await _loadReminders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Güncelleme başarısız: $e')),
        );
      }
    }
  }

  Future<void> _deleteReminder(HealthReminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hatırlatıcıyı Sil'),
        content: Text('"${reminder.title}" kalıcı olarak silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _notificationService.cancelReminder(reminder.id);
      await _supabase.from('health_reminders').delete().eq('id', reminder.id);
      await _loadReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hatırlatıcı silindi'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silme başarısız: $e')),
        );
      }
    }
  }

  void _openForm({HealthReminder? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReminderFormSheet(
        existing: existing,
        onSaved: () {
          Navigator.pop(ctx);
          _loadReminders();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: const Text(
          'Sağlık Hatırlatıcıları',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Yeni Hatırlatıcı', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : RefreshIndicator(
              onRefresh: _loadReminders,
              color: AppColors.primaryBlue,
              child: CustomScrollView(
                slivers: [
                  if (!_notificationsEnabled)
                    SliverToBoxAdapter(child: _buildPermissionBanner()),
                  SliverToBoxAdapter(child: _buildSummaryHeader()),
                  SliverToBoxAdapter(child: _buildFilterChips()),
                  _filtered.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildReminderCard(_filtered[index]),
                              childCount: _filtered.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_off_outlined, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bildirimler kapalı. Hatırlatıcıların çalışması için izin verin.',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _notificationService.requestPermissions();
              final enabled = await _notificationService.areNotificationsEnabled();
              if (mounted) {
                setState(() => _notificationsEnabled = enabled);
                if (enabled) await _syncNotifications();
              }
            },
            child: const Text('İzin Ver'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue, Colors.blue.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryStat('Aktif', '$_activeCount', Icons.check_circle_outline),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _summaryStat('Yaklaşan', '$_upcomingCount', Icons.schedule),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _summaryStat('Toplam', '${_reminders.length}', Icons.list_alt),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _filterChip(null, 'Tümü'),
          ...ReminderType.values.map((t) => _filterChip(t, t.label)),
        ],
      ),
    );
  }

  Widget _filterChip(ReminderType? type, String label) {
    final selected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 16),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filterType = type),
        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
        checkmarkColor: AppColors.primaryBlue,
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryBlue : AppColors.textDarkGrey,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(
          color: selected ? AppColors.primaryBlue : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _filterType != null
                  ? 'Bu kategoride hatırlatıcı yok'
                  : 'Henüz hatırlatıcı eklemediniz',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlaç, hastane randevusu veya kontrol\nhatırlatıcılarınızı buradan yönetin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(HealthReminder reminder) {
    final typeColor = reminder.type.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reminder.isActive
              ? typeColor.withValues(alpha: 0.2)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openForm(existing: reminder),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(reminder.type.icon, color: typeColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reminder.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: reminder.isActive
                                    ? AppColors.textDarkGrey
                                    : Colors.grey,
                                decoration: reminder.isActive
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: reminder.isActive,
                            onChanged: (_) => _toggleActive(reminder),
                            activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                            activeThumbColor: AppColors.primaryBlue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            reminder.nextOccurrenceLabel,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      if (reminder.dosage != null && reminder.dosage!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Doz: ${reminder.dosage}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                      if (reminder.location != null && reminder.location!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.place_outlined, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                reminder.location!,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (reminder.doctorName != null && reminder.doctorName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Dr. ${reminder.doctorName}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                      if (reminder.isRecurring && reminder.repeatDays.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          children: reminder.repeatDays.map((d) {
                            final label = kWeekDays
                                .firstWhere(
                                  (w) => w.$1 == d,
                                  orElse: () => (d, d),
                                )
                                .$2;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(fontSize: 10, color: typeColor),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.withValues(alpha: 0.6)),
                  onPressed: () => _deleteReminder(reminder),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderFormSheet extends StatefulWidget {
  final HealthReminder? existing;
  final VoidCallback onSaved;

  const _ReminderFormSheet({this.existing, required this.onSaved});

  @override
  State<_ReminderFormSheet> createState() => _ReminderFormSheetState();
}

class _ReminderFormSheetState extends State<_ReminderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _doctorCtrl;
  late TextEditingController _dosageCtrl;

  ReminderType _type = ReminderType.medication;
  DateTime? _date;
  TimeOfDay? _time;
  bool _isRecurring = false;
  final Set<String> _selectedDays = {};
  int _notifyBefore = 30;
  bool _isSaving = false;
  String? _userMedicationId;
  UserMedication? _selectedUserMed;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _doctorCtrl = TextEditingController(text: e?.doctorName ?? '');
    _dosageCtrl = TextEditingController(text: e?.dosage ?? '');
    if (e != null) {
      _type = e.type;
      _date = e.scheduledDate;
      _time = e.scheduledTime;
      _isRecurring = e.isRecurring;
      _selectedDays.addAll(e.repeatDays);
      _notifyBefore = e.notifyBeforeMinutes;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _doctorCtrl.dispose();
    _dosageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primaryBlue)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primaryBlue)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickFromMyMedications() async {
    final picked = await MedicationPickerSheet.pick(context);
    if (picked == null) return;
    setState(() {
      _selectedUserMed = picked;
      _userMedicationId = picked.id;
      _titleCtrl.text = picked.medication.name;
      _dosageCtrl.text = picked.displayDosage;
      _descCtrl.text =
          'Etken: ${picked.medication.activeIngredient}\n'
          'Sorun: ${picked.medication.targetCondition}\n'
          '${picked.medication.prescriptionType}'
          '${picked.frequency != null ? '\nSıklık: ${picked.frequency}' : ''}';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final data = {
        'user_id': user.id,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'reminder_type': _type.value,
        'scheduled_date': _date != null
            ? '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}'
            : null,
        'scheduled_time': _time != null
            ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}:00'
            : null,
        'repeat_days': _selectedDays.toList(),
        'is_recurring': _isRecurring,
        'location': _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        'doctor_name': _doctorCtrl.text.trim().isEmpty ? null : _doctorCtrl.text.trim(),
        'dosage': _dosageCtrl.text.trim().isEmpty ? null : _dosageCtrl.text.trim(),
        'is_active': true,
        'notify_before_minutes': _notifyBefore,
        'user_medication_id': _userMedicationId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.existing != null) {
        await _supabase
            .from('health_reminders')
            .update(data)
            .eq('id', widget.existing!.id);
      } else {
        await _supabase.from('health_reminders').insert(data);
      }

      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existing != null ? 'Hatırlatıcı güncellendi' : 'Hatırlatıcı eklendi'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt başarısız: $e')),
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
                  widget.existing != null ? 'Hatırlatıcıyı Düzenle' : 'Yeni Hatırlatıcı',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDarkGrey,
                  ),
                ),
                const SizedBox(height: 20),

                Text('Tür', style: _labelStyle()),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ReminderType.values.map((t) {
                    final selected = _type == t;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.icon, size: 16, color: selected ? t.color : Colors.grey),
                          const SizedBox(width: 4),
                          Text(t.label),
                        ],
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() => _type = t),
                      selectedColor: t.color.withValues(alpha: 0.15),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                if (_type == ReminderType.medication) ...[
                  OutlinedButton.icon(
                    onPressed: _pickFromMyMedications,
                    icon: const Icon(Icons.medication_liquid),
                    label: Text(
                      _selectedUserMed != null
                          ? 'Seçili: ${_selectedUserMed!.medication.name}'
                          : 'İlaçlarımdan Seç',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: BorderSide(color: ReminderType.medication.color.withValues(alpha: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _titleCtrl,
                  decoration: _inputDec(
                    _type == ReminderType.medication
                        ? 'İlaç Adı'
                        : _type == ReminderType.appointment
                            ? 'Randevu Başlığı'
                            : 'Başlık',
                    Icons.title,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Başlık gerekli' : null,
                ),
                const SizedBox(height: 12),

                if (_type == ReminderType.medication)
                  TextFormField(
                    controller: _dosageCtrl,
                    decoration: _inputDec('Doz (ör. 1 tablet, 500mg)', Icons.medication),
                  ),
                if (_type == ReminderType.medication) const SizedBox(height: 12),

                if (_type == ReminderType.appointment || _type == ReminderType.checkup) ...[
                  TextFormField(
                    controller: _doctorCtrl,
                    decoration: _inputDec('Doktor Adı (opsiyonel)', Icons.person_outline),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationCtrl,
                    decoration: _inputDec('Hastane / Klinik Adresi', Icons.local_hospital_outlined),
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: _inputDec('Notlar (opsiyonel)', Icons.notes),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _date != null
                              ? '${_date!.day}.${_date!.month}.${_date!.year}'
                              : 'Tarih Seç',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(
                          _time != null
                              ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'
                              : 'Saat Seç',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tekrarlayan hatırlatıcı'),
                  subtitle: const Text('Her hafta belirli günlerde tekrarla'),
                  value: _isRecurring,
                  activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                  activeThumbColor: AppColors.primaryBlue,
                  onChanged: (v) => setState(() {
                    _isRecurring = v;
                    if (!v) _selectedDays.clear();
                  }),
                ),

                if (_isRecurring) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kWeekDays.map((day) {
                      final selected = _selectedDays.contains(day.$1);
                      return FilterChip(
                        label: Text(day.$2),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            if (selected) {
                              _selectedDays.remove(day.$1);
                            } else {
                              _selectedDays.add(day.$1);
                            }
                          });
                        },
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                Text('Önceden hatırlat', style: _labelStyle()),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 15, label: Text('15 dk')),
                    ButtonSegment(value: 30, label: Text('30 dk')),
                    ButtonSegment(value: 60, label: Text('1 saat')),
                  ],
                  selected: {_notifyBefore},
                  onSelectionChanged: (s) => setState(() => _notifyBefore = s.first),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            widget.existing != null ? 'Güncelle' : 'Kaydet',
                            style: const TextStyle(
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

  TextStyle _labelStyle() => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      );

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
