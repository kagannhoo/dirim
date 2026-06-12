import 'package:flutter/material.dart';

class Medication {
  final String id;
  final String name;
  final String category;
  final String targetCondition;
  final String activeIngredient;
  final String prescriptionType;

  const Medication({
    required this.id,
    required this.name,
    required this.category,
    required this.targetCondition,
    required this.activeIngredient,
    required this.prescriptionType,
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'].toString(),
      name: map['medication_name'] ?? '',
      category: map['category'] ?? '',
      targetCondition: map['target_condition'] ?? '',
      activeIngredient: map['active_ingredient'] ?? '',
      prescriptionType: map['prescription_type'] ?? '',
    );
  }

  bool get isPrescriptionRequired =>
      prescriptionType.toLowerCase().contains('reçeteli') &&
      !prescriptionType.toLowerCase().contains('reçetesiz');

  Color get prescriptionColor {
    final t = prescriptionType.toLowerCase();
    if (t.contains('kırmızı')) return const Color(0xFFE74C3C);
    if (t.contains('yeşil') && t.contains('reçeteli')) return const Color(0xFF27AE60);
    if (t.contains('reçeteli')) return const Color(0xFFE67E22);
    return const Color(0xFF27AE60);
  }

  IconData get categoryIcon {
    final c = category.toLowerCase();
    if (c.contains('ağrı')) return Icons.healing_outlined;
    if (c.contains('soğuk') || c.contains('grip')) return Icons.coronavirus_outlined;
    if (c.contains('gastro')) return Icons.restaurant_outlined;
    if (c.contains('kardiyo')) return Icons.favorite_outline;
    if (c.contains('endokrin')) return Icons.bloodtype_outlined;
    if (c.contains('solunum')) return Icons.air_outlined;
    if (c.contains('alerji')) return Icons.grass_outlined;
    if (c.contains('antibiyotik')) return Icons.biotech_outlined;
    if (c.contains('psikiyatri') || c.contains('nöroloji')) return Icons.psychology_outlined;
    if (c.contains('dermatoloji')) return Icons.face_retouching_natural_outlined;
    if (c.contains('kas') || c.contains('eklem')) return Icons.accessibility_new_outlined;
    if (c.contains('vitamin')) return Icons.energy_savings_leaf_outlined;
    if (c.contains('göz') || c.contains('kulak')) return Icons.visibility_outlined;
    if (c.contains('antiviral') || c.contains('mantar')) return Icons.shield_outlined;
    if (c.contains('üroloji')) return Icons.water_drop_outlined;
    return Icons.medication_outlined;
  }
}

class UserMedication {
  final String id;
  final String userId;
  final String medicationId;
  final String? customDosage;
  final String? frequency;
  final String? notes;
  final bool isActive;
  final Medication medication;

  const UserMedication({
    required this.id,
    required this.userId,
    required this.medicationId,
    this.customDosage,
    this.frequency,
    this.notes,
    this.isActive = true,
    required this.medication,
  });

  factory UserMedication.fromMap(Map<String, dynamic> map) {
    final medData = map['medications'];
    return UserMedication(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      medicationId: map['medication_id'].toString(),
      customDosage: map['custom_dosage'],
      frequency: map['frequency'],
      notes: map['notes'],
      isActive: map['is_active'] != false,
      medication: Medication.fromMap(
        medData is Map ? Map<String, dynamic>.from(medData) : map,
      ),
    );
  }

  String get displayDosage => customDosage ?? medication.name;
}

const kMedicationFrequencies = [
  'Günde 1 kez',
  'Günde 2 kez',
  'Günde 3 kez',
  'Haftada 1 kez',
  'İhtiyaç halinde',
  'Doktor önerisine göre',
];
