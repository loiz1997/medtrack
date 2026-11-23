enum TxStatus { pending, accepted, completed, declined }

extension TxStatusX on TxStatus {
  String get label {
    switch (this) {
      case TxStatus.pending:
        return 'Pending';
      case TxStatus.accepted:
        return 'Accepted';
      case TxStatus.completed:
        return 'Completed';
      case TxStatus.declined:
        return 'Declined';
    }
  }

  static TxStatus fromLabel(String label) {
    switch (label) {
      case 'Accepted':
        return TxStatus.accepted;
      case 'Completed':
        return TxStatus.completed;
      case 'Declined':
        return TxStatus.declined;
      default:
        return TxStatus.pending;
    }
  }
}

extension TxStatusColorX on TxStatus {
  /// A consistent color for this status, used across dashboard, patient,
  /// and doctor screens so the same status always looks the same.
  int get colorValue {
    switch (this) {
      case TxStatus.pending:
        return 0xFFF59E0B; // amber
      case TxStatus.accepted:
        return 0xFF2563EB; // blue
      case TxStatus.completed:
        return 0xFF16A34A; // green
      case TxStatus.declined:
        return 0xFFDC2626; // red
    }
  }
}

class ClinicTransaction {
  final String id; // e.g. TX-1001
  final String patientId;
  final String patientName; // denormalized for fast list rendering
  final String doctorId;
  final String doctorName; // denormalized
  final String type;
  final double amount;
  final TxStatus status;
  final DateTime visitDate;

  ClinicTransaction({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.type,
    required this.amount,
    required this.status,
    required this.visitDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'patient_id': patientId,
        'patient_name': patientName,
        'doctor_id': doctorId,
        'doctor_name': doctorName,
        'type': type,
        'amount': amount,
        'status': status.label,
        'visit_date': visitDate.toIso8601String(),
      };

  factory ClinicTransaction.fromMap(Map<String, dynamic> map) => ClinicTransaction(
        id: map['id'] as String,
        patientId: map['patient_id'] as String,
        patientName: map['patient_name'] as String,
        doctorId: map['doctor_id'] as String,
        doctorName: map['doctor_name'] as String,
        type: map['type'] as String,
        amount: (map['amount'] as num).toDouble(),
        status: TxStatusX.fromLabel(map['status'] as String),
        visitDate: DateTime.parse(map['visit_date'] as String),
      );
}
