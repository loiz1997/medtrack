import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/patient.dart';
import '../models/doctor.dart';
import '../models/clinic_transaction.dart';
import '../widgets/test_id.dart';

/// Opened by tapping "Total patients" on the dashboard — shows every
/// patient in the clinic, grouped by which doctor they've seen.
class AllPatientsByDoctorScreen extends StatefulWidget {
  const AllPatientsByDoctorScreen({super.key});

  @override
  State<AllPatientsByDoctorScreen> createState() => _AllPatientsByDoctorScreenState();
}

class _AllPatientsByDoctorScreenState extends State<AllPatientsByDoctorScreen> {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  List<Doctor> _doctors = [];
  Map<String, List<Patient>> _patientsByDoctor = {};
  List<Patient> _unassigned = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doctors = await _db.getDoctors();
    final allPatients = await _db.getPatients();
    final transactions = await _db.getTransactions();

    final grouping = <String, List<Patient>>{};
    final assignedPatientIds = <String>{};

    for (final doctor in doctors) {
      final patientIdsForDoctor = transactions
          .where((t) => t.doctorId == doctor.id)
          .map((t) => t.patientId)
          .toSet();
      final list = allPatients.where((p) => patientIdsForDoctor.contains(p.id)).toList();
      grouping[doctor.id] = list;
      assignedPatientIds.addAll(patientIdsForDoctor);
    }

    setState(() {
      _doctors = doctors;
      _patientsByDoctor = grouping;
      _unassigned = allPatients.where((p) => !assignedPatientIds.contains(p.id)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('all_patients_by_doctor_screen'),
      appBar: AppBar(title: const Text('All patients by doctor'), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final doctor in _doctors) ...[
                  Text(doctor.fullName, style: Theme.of(context).textTheme.titleMedium),
                  Text(doctor.specialty, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 8),
                  if ((_patientsByDoctor[doctor.id] ?? []).isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text('No patients yet', style: TextStyle(color: Colors.grey.shade500)),
                    )
                  else
                    ...(_patientsByDoctor[doctor.id] ?? []).map((p) => TestId.group('all_patients_row_${doctor.id}_${p.id}', Card(
                          key: Key('all_patients_row_${doctor.id}_${p.id}'),
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_outline),
                            title: Text(p.fullName),
                            subtitle: Text(p.condition),
                            trailing: Text(p.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                          ),
                        ))),
                  const SizedBox(height: 16),
                ],
                if (_unassigned.isNotEmpty) ...[
                  Text('Not yet booked with a doctor', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._unassigned.map((p) => TestId.group('all_patients_unassigned_${p.id}', Card(
                        key: Key('all_patients_unassigned_${p.id}'),
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.person_outline),
                          title: Text(p.fullName),
                          subtitle: Text(p.condition),
                          trailing: Text(p.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        ),
                      ))),
                ],
              ],
            ),
    );
  }
}
