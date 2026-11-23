import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/doctor.dart';
import '../models/clinic_transaction.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../widgets/test_id.dart';

/// Lets a patient request an appointment with any active doctor. The
/// request starts as "Pending" — the doctor accepts or declines it from
/// their own Appointments screen.
class BookAppointmentScreen extends StatefulWidget {
  final Patient patient;

  const BookAppointmentScreen({super.key, required this.patient});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _db = DatabaseHelper.instance;
  List<Doctor> _doctors = [];
  Doctor? _selectedDoctor;
  final _reasonCtrl = TextEditingController(text: 'Consultation');
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    final doctors = await _db.getActiveDoctors();
    setState(() {
      _doctors = doctors;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (_selectedDoctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a doctor first')),
      );
      return;
    }

    setState(() => _submitting = true);
    final id = await _db.nextTransactionId();
    await _db.insertTransaction(ClinicTransaction(
      id: id,
      patientId: widget.patient.id,
      patientName: widget.patient.fullName,
      doctorId: _selectedDoctor!.id,
      doctorName: _selectedDoctor!.fullName,
      type: _reasonCtrl.text.trim().isEmpty ? 'Consultation' : _reasonCtrl.text.trim(),
      amount: 0,
      status: TxStatus.pending,
      visitDate: DateTime.now(),
    ));
    SyncService.instance.syncAll();
    setState(() => _submitting = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appointment request sent — waiting for the doctor to respond')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('book_appointment_screen'),
      appBar: AppBar(title: const Text('Book an appointment'), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _doctors.isEmpty
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No doctors are available to book right now. Please try again later.'),
                ))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Choose a doctor', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._doctors.map((d) => TestId.group('doctor_option_${d.id}', Card(
                          key: Key('doctor_option_${d.id}'),
                          margin: const EdgeInsets.only(bottom: 8),
                          color: _selectedDoctor?.id == d.id
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: ListTile(
                            leading: const Icon(Icons.medical_services_outlined),
                            title: Text(d.fullName),
                            subtitle: Text('${d.specialty}\n${d.schedule}'),
                            isThreeLine: true,
                            trailing: _selectedDoctor?.id == d.id ? const Icon(Icons.check_circle) : null,
                            onTap: () => setState(() => _selectedDoctor = d),
                          ),
                        ))),
                    const SizedBox(height: 16),
                    TestId.field('appointment_reason_input', TextField(
                      key: const Key('appointment_reason_input'),
                      controller: _reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reason for visit',
                        border: OutlineInputBorder(),
                      ),
                    )),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TestId.button('submit_appointment_button', FilledButton(
                        key: const Key('submit_appointment_button'),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Request appointment'),
                      ), label: 'Request appointment'),
                    ),
                  ],
                ),
    );
  }
}
