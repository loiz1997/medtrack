import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../models/clinic_transaction.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../widgets/test_id.dart';

/// Where a doctor manages incoming appointment requests: accept or decline
/// a pending one, and mark an accepted one as completed once the visit
/// happens. Only appointments booked with THIS doctor show up here.
class DoctorAppointmentsScreen extends StatefulWidget {
  final Doctor doctor;

  const DoctorAppointmentsScreen({super.key, required this.doctor});

  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  final _db = DatabaseHelper.instance;
  List<ClinicTransaction> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await _db.getTransactions(doctorId: widget.doctor.id);
    setState(() {
      _appointments = results;
      _loading = false;
    });
  }

  Future<void> _updateStatus(String id, TxStatus status) async {
    await _db.updateTransactionStatus(id, status);
    SyncService.instance.syncAll();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Appointment marked ${status.label}')));
    }
  }

  Color _statusColor(TxStatus status) => Color(status.colorValue);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('doctor_appointments_screen'),
      appBar: AppBar(title: const Text('Appointments'), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? const Center(child: Text('No appointments yet'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: TestId.group('doctor_appointments_list', ListView.builder(
                    key: const Key('doctor_appointments_list'),
                    padding: const EdgeInsets.all(12),
                    itemCount: _appointments.length,
                    itemBuilder: (context, i) {
                      final t = _appointments[i];
                      return TestId.group('doctor_appointment_card_${t.id}', Card(
                        key: Key('doctor_appointment_card_${t.id}'),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.patientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text('${t.type} · ${t.visitDate.toString().split(' ').first}'),
                                      ],
                                    ),
                                  ),
                                  TestId.group('doctor_appointment_status_${t.id}', Chip(
                                    key: Key('doctor_appointment_status_${t.id}'),
                                    label: Text(t.status.label, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                    backgroundColor: _statusColor(t.status),
                                  )),
                                ],
                              ),
                              if (t.status == TxStatus.pending) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TestId.button('doctor_decline_button_${t.id}', OutlinedButton.icon(
                                        key: Key('doctor_decline_button_${t.id}'),
                                        onPressed: () => _updateStatus(t.id, TxStatus.declined),
                                        icon: const Icon(Icons.close, size: 18),
                                        label: const Text('Decline'),
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                      ), label: 'Decline'),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TestId.button('doctor_accept_button_${t.id}', FilledButton.icon(
                                        key: Key('doctor_accept_button_${t.id}'),
                                        onPressed: () => _updateStatus(t.id, TxStatus.accepted),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text('Accept'),
                                      ), label: 'Accept'),
                                    ),
                                  ],
                                ),
                              ] else if (t.status == TxStatus.accepted) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: TestId.button('doctor_complete_button_${t.id}', FilledButton.icon(
                                    key: Key('doctor_complete_button_${t.id}'),
                                    onPressed: () => _updateStatus(t.id, TxStatus.completed),
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: const Text('Mark completed'),
                                  ), label: 'Mark completed'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ));
                    },
                  )),
                ),
    );
  }
}
