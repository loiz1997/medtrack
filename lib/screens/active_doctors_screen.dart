import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/doctor.dart';

/// Opened by tapping "Active doctors" on the dashboard.
class ActiveDoctorsScreen extends StatefulWidget {
  const ActiveDoctorsScreen({super.key});

  @override
  State<ActiveDoctorsScreen> createState() => _ActiveDoctorsScreenState();
}

class _ActiveDoctorsScreenState extends State<ActiveDoctorsScreen> {
  final _db = DatabaseHelper.instance;
  List<Doctor> _doctors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doctors = await _db.getActiveDoctors();
    setState(() {
      _doctors = doctors;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('active_doctors_screen'),
      appBar: AppBar(title: const Text('Active doctors'), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _doctors.isEmpty
              ? const Center(child: Text('No active doctors right now'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _doctors.length,
                  itemBuilder: (context, i) {
                    final d = _doctors[i];
                    return Card(
                      key: Key('active_doctor_row_${d.id}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.medical_services_outlined)),
                        title: Text(d.fullName),
                        subtitle: Text('${d.specialty}\n${d.schedule}'),
                        isThreeLine: true,
                        trailing: Text(d.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      ),
                    );
                  },
                ),
    );
  }
}
