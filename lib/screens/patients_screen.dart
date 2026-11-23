import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../models/patient.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();
  List<Patient> _patients = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await _db.getPatients(query: _searchController.text);
    setState(() => _patients = results);
  }

  Future<void> _openRegisterSheet() async {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final conditionCtrl = TextEditingController();
    String gender = 'Female';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Register new patient', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) => setSheetState(() => gender = v ?? 'Female'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Contact number')),
                const SizedBox(height: 12),
                TextField(controller: conditionCtrl, decoration: const InputDecoration(labelText: 'Reason for visit')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
                      final id = await _db.nextPatientId();
                      await _db.insertPatient(Patient(
                        id: id,
                        fullName: nameCtrl.text.trim(),
                        age: int.tryParse(ageCtrl.text) ?? 0,
                        gender: gender,
                        phone: phoneCtrl.text.trim(),
                        condition: conditionCtrl.text.trim().isEmpty ? 'General checkup' : conditionCtrl.text.trim(),
                        registeredAt: DateTime.now(),
                      ));
                      // Mail a copy of this new patient to the cloud database,
                      // if the app has internet right now. If not, it stays
                      // marked "dirty" and will sync automatically next time
                      // this (or any) sync call runs.
                      SyncService.instance.syncAll();
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                      if (mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Registered ${nameCtrl.text} as $id')));
                      }
                    },
                    child: const Text('Register patient'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Import patients from a .csv file exported by Excel — replaces the
  /// manual copy-paste-into-a-new-sheet workflow entirely.
  Future<void> _importFromExcelCsv() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null || result.files.single.bytes == null) return;

    final content = utf8.decode(result.files.single.bytes!);
    final rows = CsvToListConverter(eol: '\n').convert(content);
    if (rows.length < 2) return;

    final headers = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
    int imported = 0;

    for (final row in rows.skip(1)) {
      final map = <String, String>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        map[headers[i]] = row[i].toString();
      }
      if ((map['name'] ?? '').trim().isEmpty) continue;
      final id = await _db.nextPatientId();
      await _db.insertPatient(Patient.fromCsvRow(map, id));
      imported++;
    }

    SyncService.instance.syncAll();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $imported patients from spreadsheet')));
    }
  }

  Future<void> _toggleActive(Patient p, bool active) async {
    await _db.setPatientActive(p.id, active);
    SyncService.instance.syncAll();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${p.fullName} is now ${active ? 'active' : 'inactive'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('admin_patients_screen'),
      appBar: AppBar(
        title: const Text('Patients'),
        centerTitle: false,
        actions: [
          IconButton(
            key: const Key('admin_import_csv_button'),
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import from Excel (CSV)',
            onPressed: _importFromExcelCsv,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('admin_register_patient_fab'),
        onPressed: _openRegisterSheet,
        icon: const Icon(Icons.add),
        label: const Text('Register patient'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('admin_patients_search_input'),
              controller: _searchController,
              onChanged: (_) => _load(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name, ID, or condition',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _patients.isEmpty
                ? const Center(child: Text('No patients found'))
                : ListView.builder(
                    key: const Key('admin_patients_list'),
                    itemCount: _patients.length,
                    itemBuilder: (context, i) {
                      final p = _patients[i];
                      return ListTile(
                        key: Key('admin_patient_row_${p.id}'),
                        leading: CircleAvatar(child: Text(p.fullName.isNotEmpty ? p.fullName[0] : '?')),
                        title: Text(p.fullName, style: TextStyle(color: p.isActive ? null : Colors.grey)),
                        subtitle: Text('${p.condition} · ${p.age} yrs, ${p.gender}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                            const SizedBox(width: 8),
                            Container(
                              key: Key('admin_patient_status_badge_${p.id}'),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: p.isActive ? Colors.green.shade50 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                p.status, // "active" or "inactive"
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: p.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              key: Key('admin_patient_active_toggle_${p.id}'),
                              value: p.isActive,
                              onChanged: (v) => _toggleActive(p, v),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
