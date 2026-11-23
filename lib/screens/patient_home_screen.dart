import 'dart:io';
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/clinic_transaction.dart';
import '../services/database_helper.dart';
import 'login_screen.dart';
import 'patient_edit_profile_screen.dart';
import 'book_appointment_screen.dart';
import '../widgets/test_id.dart';

/// What a patient sees after logging in — their own info and appointment
/// history only, not the full staff dashboard (patients shouldn't see other
/// patients' records).
///
/// Every tappable/enterable element below has a `key: Key('...')` set.
/// Flutter doesn't have an HTML-style `data-test-id` attribute, but a Key
/// is the direct equivalent for automated testing tools like Katalon/
/// Appium — it shows up as a stable identifier the test can target,
/// the same way a data-test-id would on a web page.
class PatientHomeScreen extends StatefulWidget {
  final Patient patient;

  const PatientHomeScreen({super.key, required this.patient});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final _db = DatabaseHelper.instance;
  late Patient _patient;
  List<ClinicTransaction> _visits = [];

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    _load();
  }

  Future<void> _load() async {
    final results = await _db.getTransactions(patientId: _patient.id);
    setState(() => _visits = results);
  }

  void _logout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(onDoctorLogin: (_) => const SizedBox())),
    );
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<Patient>(
      MaterialPageRoute(builder: (_) => PatientEditProfileScreen(patient: _patient)),
    );
    if (updated != null) {
      setState(() => _patient = updated);
    }
  }

  Future<void> _openBookAppointment() async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BookAppointmentScreen(patient: _patient)),
    );
    if (booked == true) _load();
  }

  Color _statusColor(TxStatus status) => Color(status.colorValue);

  @override
  Widget build(BuildContext context) {
    final p = _patient;
    return Scaffold(
      key: const Key('patient_home_screen'),
      appBar: AppBar(
        title: const Text('My MedTrack'),
        centerTitle: false,
        actions: [
          TestId.button('patient_logout_button', IconButton(
            key: const Key('patient_logout_button'),
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ), label: 'Log out'),
        ],
      ),
      floatingActionButton: TestId.button('patient_book_appointment_fab', FloatingActionButton.extended(
        key: const Key('patient_book_appointment_fab'),
        onPressed: _openBookAppointment,
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('Book appointment'),
      ), label: 'Book appointment'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: TestId.group('patient_home_list', ListView(
          key: const Key('patient_home_list'),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _ProfileAvatar(patient: p),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          Text('${p.age} yrs · ${p.gender}', style: TextStyle(color: Colors.grey.shade600)),
                          Text(p.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        ],
                      ),
                    ),
                    TestId.button('patient_edit_profile_button', IconButton(
                      key: const Key('patient_edit_profile_button'),
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit profile',
                      onPressed: _openEditProfile,
                    ), label: 'Edit profile'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('My appointments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_visits.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No appointments yet — tap "Book appointment" to get started.')),
              )
            else
              ..._visits.map((t) => TestId.group('patient_appointment_card_${t.id}', Card(
                    key: Key('patient_appointment_card_${t.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(t.type),
                      subtitle: Text('${t.doctorName} · ${t.visitDate.toString().split(' ').first}'),
                      trailing: TestId.group('patient_appointment_status_${t.id}', Chip(
                        key: Key('patient_appointment_status_${t.id}'),
                        label: Text(t.status.label, style: const TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: _statusColor(t.status),
                      )),
                    ),
                  ))),
          ],
        )),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final Patient patient;
  const _ProfileAvatar({required this.patient});

  @override
  Widget build(BuildContext context) {
    final path = patient.photoPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return TestId.group('patient_profile_photo', CircleAvatar(key: const Key('patient_profile_photo'), radius: 28, backgroundImage: FileImage(File(path))));
    }
    return TestId.group('patient_profile_photo_placeholder', CircleAvatar(
      key: const Key('patient_profile_photo_placeholder'),
      radius: 28,
      child: Text(patient.fullName.isNotEmpty ? patient.fullName[0] : '?'),
    ));
  }
}
