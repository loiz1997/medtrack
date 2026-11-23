import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../models/patient.dart';
import '../services/database_helper.dart';
import '../widgets/test_id.dart';

/// A doctor only ever sees patients who have booked an appointment with
/// them specifically — never the whole clinic's patient list. There is no
/// "register patient" button here on purpose: patients create their own
/// accounts (Sign Up) or are registered by front-desk/admin staff.
class DoctorPatientsScreen extends StatefulWidget {
  final Doctor doctor;

  const DoctorPatientsScreen({super.key, required this.doctor});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final _db = DatabaseHelper.instance;
  List<Patient> _patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await _db.getPatientsForDoctor(widget.doctor.id);
    setState(() {
      _patients = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('doctor_patients_screen'),
      appBar: AppBar(title: const Text('My Patients'), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _patients.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No patients have booked with you yet.'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: TestId.group('doctor_patients_list', ListView.builder(
                    key: const Key('doctor_patients_list'),
                    padding: const EdgeInsets.all(12),
                    itemCount: _patients.length,
                    itemBuilder: (context, i) {
                      final p = _patients[i];
                      return TestId.group('doctor_patient_row_${p.id}', Card(
                        key: Key('doctor_patient_row_${p.id}'),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(child: Text(p.fullName.isNotEmpty ? p.fullName[0] : '?')),
                          title: Text(p.fullName),
                          subtitle: Text('${p.condition} · ${p.age} yrs, ${p.gender}'),
                          trailing: Text(p.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        ),
                      ));
                    },
                  )),
                ),
    );
  }
}
