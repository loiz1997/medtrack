class Doctor {
  final String id; // e.g. DR-001
  final String fullName;
  final String specialty;
  final String schedule;
  final bool isActive; // set by the admin — inactive accounts can't log in

  Doctor({
    required this.id,
    required this.fullName,
    required this.specialty,
    required this.schedule,
    this.isActive = true,
  });

  /// Human-readable "active" / "inactive" text, stored alongside is_active
  /// so it's plainly visible when looking directly at the database table.
  String get status => isActive ? 'active' : 'inactive';

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'specialty': specialty,
        'schedule': schedule,
        'is_active': isActive ? 1 : 0,
        'status': status,
      };

  factory Doctor.fromMap(Map<String, dynamic> map) => Doctor(
        id: map['id'] as String,
        fullName: map['full_name'] as String,
        specialty: map['specialty'] as String,
        schedule: map['schedule'] as String? ?? '',
        // is_active is the source of truth; status text is kept in sync
        // with it automatically, so reading only needs is_active.
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );
}
