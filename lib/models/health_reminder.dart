import 'package:flutter/material.dart';

enum ReminderType { medication, appointment, checkup, custom }

extension ReminderTypeExt on ReminderType {
  String get value {
    switch (this) {
      case ReminderType.medication:
        return 'medication';
      case ReminderType.appointment:
        return 'appointment';
      case ReminderType.checkup:
        return 'checkup';
      case ReminderType.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case ReminderType.medication:
        return 'İlaç';
      case ReminderType.appointment:
        return 'Randevu';
      case ReminderType.checkup:
        return 'Kontrol';
      case ReminderType.custom:
        return 'Özel';
    }
  }

  IconData get icon {
    switch (this) {
      case ReminderType.medication:
        return Icons.medication_outlined;
      case ReminderType.appointment:
        return Icons.local_hospital_outlined;
      case ReminderType.checkup:
        return Icons.monitor_heart_outlined;
      case ReminderType.custom:
        return Icons.notifications_outlined;
    }
  }

  Color get color {
    switch (this) {
      case ReminderType.medication:
        return const Color(0xFF6C5CE7);
      case ReminderType.appointment:
        return const Color(0xFF00B894);
      case ReminderType.checkup:
        return const Color(0xFFE17055);
      case ReminderType.custom:
        return const Color(0xFF007AFF);
    }
  }

  static ReminderType fromString(String? value) {
    switch (value) {
      case 'medication':
        return ReminderType.medication;
      case 'appointment':
        return ReminderType.appointment;
      case 'checkup':
        return ReminderType.checkup;
      default:
        return ReminderType.custom;
    }
  }
}

class HealthReminder {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final ReminderType type;
  final DateTime? scheduledDate;
  final TimeOfDay? scheduledTime;
  final List<String> repeatDays;
  final bool isRecurring;
  final String? location;
  final String? doctorName;
  final String? dosage;
  final bool isActive;
  final int notifyBeforeMinutes;

  const HealthReminder({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.type,
    this.scheduledDate,
    this.scheduledTime,
    this.repeatDays = const [],
    this.isRecurring = false,
    this.location,
    this.doctorName,
    this.dosage,
    this.isActive = true,
    this.notifyBeforeMinutes = 30,
  });

  factory HealthReminder.fromMap(Map<String, dynamic> map) {
    TimeOfDay? time;
    final timeStr = map['scheduled_time']?.toString();
    if (timeStr != null && timeStr.isNotEmpty) {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        time = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    DateTime? date;
    final dateStr = map['scheduled_date']?.toString();
    if (dateStr != null && dateStr.isNotEmpty) {
      date = DateTime.tryParse(dateStr);
    }

    final repeatRaw = map['repeat_days'];
    List<String> days = [];
    if (repeatRaw is List) {
      days = repeatRaw.map((e) => e.toString()).toList();
    }

    return HealthReminder(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      title: map['title'] ?? '',
      description: map['description'],
      type: ReminderTypeExt.fromString(map['reminder_type']),
      scheduledDate: date,
      scheduledTime: time,
      repeatDays: days,
      isRecurring: map['is_recurring'] == true,
      location: map['location'],
      doctorName: map['doctor_name'],
      dosage: map['dosage'],
      isActive: map['is_active'] != false,
      notifyBeforeMinutes: (map['notify_before_minutes'] as num?)?.toInt() ?? 30,
    );
  }

  Map<String, dynamic> toMap() {
    String? timeStr;
    if (scheduledTime != null) {
      final h = scheduledTime!.hour.toString().padLeft(2, '0');
      final m = scheduledTime!.minute.toString().padLeft(2, '0');
      timeStr = '$h:$m:00';
    }

    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'reminder_type': type.value,
      'scheduled_date': scheduledDate != null
          ? '${scheduledDate!.year}-${scheduledDate!.month.toString().padLeft(2, '0')}-${scheduledDate!.day.toString().padLeft(2, '0')}'
          : null,
      'scheduled_time': timeStr,
      'repeat_days': repeatDays,
      'is_recurring': isRecurring,
      'location': location,
      'doctor_name': doctorName,
      'dosage': dosage,
      'is_active': isActive,
      'notify_before_minutes': notifyBeforeMinutes,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  String get nextOccurrenceLabel {
    if (scheduledTime != null) {
      final h = scheduledTime!.hour.toString().padLeft(2, '0');
      final m = scheduledTime!.minute.toString().padLeft(2, '0');
      if (isRecurring && repeatDays.isNotEmpty) {
        return 'Her gün $h:$m';
      }
      if (scheduledDate != null) {
        final d = scheduledDate!;
        return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} · $h:$m';
      }
      return 'Saat $h:$m';
    }
    if (scheduledDate != null) {
      final d = scheduledDate!;
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    }
    return 'Zaman belirtilmedi';
  }

  bool get isUpcoming {
    if (!isActive) return false;
    if (scheduledDate == null && !isRecurring) return true;
    if (isRecurring) return true;
    if (scheduledDate == null) return true;
    final now = DateTime.now();
    final target = DateTime(
      scheduledDate!.year,
      scheduledDate!.month,
      scheduledDate!.day,
      scheduledTime?.hour ?? 0,
      scheduledTime?.minute ?? 0,
    );
    return target.isAfter(now) || target.isAtSameMomentAs(now);
  }
}

const kWeekDays = [
  ('pzt', 'Pzt'),
  ('sal', 'Sal'),
  ('car', 'Çar'),
  ('per', 'Per'),
  ('cum', 'Cum'),
  ('cmt', 'Cmt'),
  ('paz', 'Paz'),
];
