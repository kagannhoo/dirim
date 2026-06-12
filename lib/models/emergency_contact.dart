class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String? relationship;
  final bool isVerified;

  const EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.relationship,
    this.isVerified = false,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      relationship: map['relationship'],
      isVerified: map['is_verified'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'is_verified': isVerified,
        'updated_at': DateTime.now().toIso8601String(),
      };

  EmergencyContact copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? relationship,
    bool? isVerified,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  String get displayPhone => formatPhoneDisplay(phone);

  static String digitsOnly(String input) => input.replaceAll(RegExp(r'\D'), '');

  static String normalizeForStorage(String input) {
    final digits = digitsOnly(input);
    if (digits.length == 10 && digits.startsWith('5')) return '0$digits';
    if (digits.length == 12 && digits.startsWith('90')) return '0${digits.substring(2)}';
    if (digits.length == 11 && digits.startsWith('0')) return digits;
    return digits;
  }

  static String normalizeForDial(String input) {
    final stored = normalizeForStorage(input);
    if (stored.length == 11 && stored.startsWith('0')) {
      return '+90${stored.substring(1)}';
    }
    return stored;
  }

  static String formatPhoneDisplay(String input) {
    final d = normalizeForStorage(input);
    if (d.length != 11) return input;
    return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7, 9)} ${d.substring(9)}';
  }

  static bool isValidTurkishMobile(String input) {
    final d = normalizeForStorage(input);
    return d.length == 11 && d.startsWith('05');
  }
}

const kRelationshipOptions = [
  'Anne',
  'Baba',
  'Eş',
  'Kardeş',
  'Çocuk',
  'Arkadaş',
  'Doktor',
  'Diğer',
];
