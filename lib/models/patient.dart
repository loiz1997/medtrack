class Patient {
  final String id; // e.g. PT-0001
  final String fullName;
  final int age;
  final String gender;
  final String phone;
  final String condition;
  final DateTime registeredAt;
  final String? photoPath; // local file path to their profile photo, if set
  final bool isActive; // set by the admin — inactive accounts can't log in

  Patient({
    required this.id,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.phone,
    required this.condition,
    required this.registeredAt,
    this.photoPath,
    this.isActive = true,
  });

  /// Human-readable "active" / "inactive" text, stored alongside is_active
  /// so the status is plainly visible when looking directly at the
  /// database table (e.g. in Supabase's Table Editor), not just as a 1/0.
  String get status => isActive ? 'active' : 'inactive';

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'age': age,
        'gender': gender,
        'phone': phone,
        'condition': condition,
        'registered_at': registeredAt.toIso8601String(),
        'photo_path': photoPath,
        'is_active': isActive ? 1 : 0,
        'status': status,
      };

  factory Patient.fromMap(Map<String, dynamic> map) => Patient(
        id: map['id'] as String,
        fullName: map['full_name'] as String,
        age: map['age'] as int? ?? 0,
        gender: map['gender'] as String? ?? '',
        phone: map['phone'] as String,
        condition: map['condition'] as String? ?? '',
        registeredAt: DateTime.parse(map['registered_at'] as String),
        photoPath: map['photo_path'] as String?,
        // is_active is the source of truth; status text is kept in sync
        // with it automatically, so reading only needs is_active.
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );

  Patient copyWith({
    String? fullName,
    int? age,
    String? gender,
    String? phone,
    String? photoPath,
    bool? isActive,
  }) =>
      Patient(
        id: id,
        fullName: fullName ?? this.fullName,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        phone: phone ?? this.phone,
        condition: condition,
        registeredAt: registeredAt,
        photoPath: photoPath ?? this.photoPath,
        isActive: isActive ?? this.isActive,
      );

  /// Builds a Patient from a parsed CSV row (Excel import), matching the
  /// same column names used in the web prototype: name, age, gender, phone, condition.
  factory Patient.fromCsvRow(Map<String, String> row, String generatedId) => Patient(
        id: generatedId,
        fullName: row['name']?.trim() ?? '',
        age: int.tryParse(row['age']?.trim() ?? '') ?? 0,
        gender: row['gender']?.trim().isEmpty ?? true ? 'Unspecified' : row['gender']!.trim(),
        phone: row['phone']?.trim() ?? '',
        condition: row['condition']?.trim().isEmpty ?? true ? 'General checkup' : row['condition']!.trim(),
        registeredAt: DateTime.now(),
      );
}
