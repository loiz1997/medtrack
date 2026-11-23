import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/patient.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../widgets/test_id.dart';

/// Lets the logged-in patient change their own name, age, phone, and photo.
/// Every field has a Key set — the Flutter equivalent of a web `data-test-id`
/// — so Katalon/Appium can target each one directly.
class PatientEditProfileScreen extends StatefulWidget {
  final Patient patient;

  const PatientEditProfileScreen({super.key, required this.patient});

  @override
  State<PatientEditProfileScreen> createState() => _PatientEditProfileScreenState();
}

class _PatientEditProfileScreenState extends State<PatientEditProfileScreen> {
  final _db = DatabaseHelper.instance;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _phoneCtrl;
  late String _gender;
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.patient.fullName);
    _ageCtrl = TextEditingController(text: widget.patient.age.toString());
    _phoneCtrl = TextEditingController(text: widget.patient.phone);
    _gender = widget.patient.gender.isEmpty ? 'Female' : widget.patient.gender;
    _photoPath = widget.patient.photoPath;
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _photoPath = result.files.single.path);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and phone number can\'t be empty')),
      );
      return;
    }

    setState(() => _saving = true);
    final updated = widget.patient.copyWith(
      fullName: _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text.trim()),
      gender: _gender,
      phone: _phoneCtrl.text.trim(),
      photoPath: _photoPath,
    );
    await _db.updatePatientProfile(updated);
    SyncService.instance.syncAll();
    setState(() => _saving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('patient_edit_profile_screen'),
      appBar: AppBar(title: const Text('Edit profile'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundImage: (_photoPath != null && File(_photoPath!).existsSync())
                      ? FileImage(File(_photoPath!))
                      : null,
                  child: (_photoPath == null || !File(_photoPath!).existsSync())
                      ? Text(_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : '?', style: const TextStyle(fontSize: 28))
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: TestId.group('patient_photo_upload_button', InkWell(
                    key: const Key('patient_photo_upload_button'),
                    onTap: _pickPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TestId.field('patient_edit_name_input', TextField(
            key: const Key('patient_edit_name_input'),
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
          )),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TestId.field('patient_edit_age_input', TextField(
                  key: const Key('patient_edit_age_input'),
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TestId.field('patient_edit_gender_dropdown', DropdownButtonFormField<String>(
                  key: const Key('patient_edit_gender_dropdown'),
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v ?? 'Female'),
                )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TestId.field('patient_edit_phone_input', TextField(
            key: const Key('patient_edit_phone_input'),
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact number',
              helperText: 'You use this to log in — changing it changes your login too',
              border: OutlineInputBorder(),
            ),
          )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TestId.button('patient_save_profile_button', FilledButton(
              key: const Key('patient_save_profile_button'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save changes'),
            ), label: 'Save changes'),
          ),
        ],
      ),
    );
  }
}
