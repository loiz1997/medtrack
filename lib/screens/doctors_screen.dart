import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../models/doctor.dart';

/// The admin's doctor directory — the only place a doctor account can be
/// turned active/inactive. Add-doctor stays here too, since that's an
/// admin-side task now (doctors themselves sign up via the Sign Up screen).
class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final _db = DatabaseHelper.instance;
  List<Doctor> _doctors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await _db.getDoctors();
    setState(() => _doctors = results);
  }

  Future<void> _toggleActive(Doctor d, bool active) async {
    await _db.setDoctorActive(d.id, active);
    SyncService.instance.syncAll();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${d.fullName} is now ${active ? 'active' : 'inactive'}')),
      );
    }
  }

  Future<void> _openAddSheet() async {
    final nameCtrl = TextEditingController();
    final specialtyCtrl = TextEditingController();
    final scheduleCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add doctor', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              key: const Key('admin_add_doctor_name_input'),
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('admin_add_doctor_specialty_input'),
              controller: specialtyCtrl,
              decoration: const InputDecoration(labelText: 'Specialty'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('admin_add_doctor_schedule_input'),
              controller: scheduleCtrl,
              decoration: const InputDecoration(labelText: 'Schedule'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('admin_add_doctor_submit_button'),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || specialtyCtrl.text.trim().isEmpty) return;
                  final id = await _db.nextDoctorId();
                  await _db.insertDoctor(Doctor(
                    id: id,
                    fullName: nameCtrl.text.trim(),
                    specialty: specialtyCtrl.text.trim(),
                    schedule: scheduleCtrl.text.trim(),
                  ));
                  SyncService.instance.syncAll();
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                child: const Text('Add doctor'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('admin_doctors_screen'),
      appBar: AppBar(title: const Text('Doctors'), centerTitle: false),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('admin_add_doctor_fab'),
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add doctor'),
      ),
      body: _doctors.isEmpty
          ? const Center(child: Text('No doctors yet'))
          : ListView.builder(
              key: const Key('admin_doctors_list'),
              padding: const EdgeInsets.all(12),
              itemCount: _doctors.length,
              itemBuilder: (context, i) {
                final d = _doctors[i];
                return Card(
                  key: Key('admin_doctor_row_${d.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.medical_services_outlined)),
                    title: Text(d.fullName, style: TextStyle(color: d.isActive ? null : Colors.grey)),
                    subtitle: Text('${d.specialty}\n${d.schedule}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(d.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        const SizedBox(width: 8),
                        Container(
                          key: Key('admin_doctor_status_badge_${d.id}'),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: d.isActive ? Colors.green.shade50 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            d.status, // "active" or "inactive"
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: d.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          key: Key('admin_doctor_active_toggle_${d.id}'),
                          value: d.isActive,
                          onChanged: (v) => _toggleActive(d, v),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
