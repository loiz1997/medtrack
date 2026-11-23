import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../models/patient.dart';
import '../models/doctor.dart';
import 'patient_home_screen.dart';
import 'login_screen.dart';
import '../widgets/test_id.dart';

/// Lets a patient or doctor create their own account, instead of requiring
/// front-desk staff to register them first.
///
/// After signing up:
///   • A patient is taken straight into their own home screen.
///   • A doctor is shown their new Doctor ID + access code on screen (since
///     that code doubles as their login password) and sent back to the
///     login screen to sign in with it — this mirrors how a real "your
///     account was created, please log in" flow works.
class SignupScreen extends StatefulWidget {
  final Widget Function(Doctor doctor) onDoctorLogin;

  const SignupScreen({super.key, required this.onDoctorLogin});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _db = DatabaseHelper.instance;
  final _formKeyPatient = GlobalKey<FormState>();
  final _formKeyDoctor = GlobalKey<FormState>();

  // Patient fields
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  String _gender = 'Female';

  // Doctor fields
  final _doctorNameCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _scheduleCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() => _error = null));
  }

  Future<void> _signUpPatient() async {
    if (!_formKeyPatient.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final id = await _db.nextPatientId();
    final patient = Patient(
      id: id,
      fullName: _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text.trim()) ?? 0,
      gender: _gender,
      phone: _phoneCtrl.text.trim(),
      condition: _conditionCtrl.text.trim().isEmpty ? 'General checkup' : _conditionCtrl.text.trim(),
      registeredAt: DateTime.now(),
    );
    await _db.insertPatient(patient);
    SyncService.instance.syncAll();
    setState(() => _loading = false);

    if (!mounted) return;
    // Straight into their home screen — no separate login step needed,
    // since creating the account already proves who they are.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PatientHomeScreen(patient: patient)),
    );
  }

  Future<void> _signUpDoctor() async {
    if (!_formKeyDoctor.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final id = await _db.nextDoctorId();
    final doctor = Doctor(
      id: id,
      fullName: _doctorNameCtrl.text.trim(),
      specialty: _specialtyCtrl.text.trim(),
      schedule: _scheduleCtrl.text.trim().isEmpty ? 'Not set' : _scheduleCtrl.text.trim(),
    );
    await _db.insertDoctor(doctor);
    SyncService.instance.syncAll();
    setState(() => _loading = false);

    if (!mounted) return;
    final accessCode = id.split('-').last;

    // Show the new doctor their ID + access code before sending them to log in.
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Account created!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please remember these — you\'ll use them to log in:'),
            const SizedBox(height: 12),
            _CredentialRow(label: 'Doctor ID', value: id),
            _CredentialRow(label: 'Access code', value: accessCode),
          ],
        ),
        actions: [
          TestId.button('signup_credentials_continue_button', FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it, take me to login'),
          ), label: 'Got it, take me to login'),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(onDoctorLogin: widget.onDoctorLogin)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account'), centerTitle: false),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      TestId.group('signup_patient_tab', Tab(icon: Icon(Icons.person_outline), text: 'I\'m a patient')),
                      TestId.group('signup_doctor_tab', Tab(icon: Icon(Icons.medical_services_outlined), text: 'I\'m a doctor')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                    ),
                  IndexedStack(
                    index: _tabController.index,
                    children: [
                      // ── Patient sign-up ──
                      Form(
                        key: _formKeyPatient,
                        child: Column(
                          children: [
                            TestId.field('signup_patient_name_input', TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                            )),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TestId.field('signup_patient_age_input', TextFormField(
                                    controller: _ageCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                                  )),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TestId.field('signup_patient_gender_dropdown', DropdownButtonFormField<String>(
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
                            TestId.field('signup_patient_phone_input', TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone number',
                                helperText: 'You\'ll use this to log in later',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a phone number' : null,
                            )),
                            const SizedBox(height: 12),
                            TestId.field('signup_patient_reason_input', TextFormField(
                              controller: _conditionCtrl,
                              decoration: const InputDecoration(labelText: 'Reason for visit (optional)', border: OutlineInputBorder()),
                            )),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: TestId.button('signup_patient_submit_button', FilledButton(
                                onPressed: _loading ? null : _signUpPatient,
                                child: _loading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Create my account'),
                              ), label: 'Create my account'),
                            ),
                          ],
                        ),
                      ),
                      // ── Doctor sign-up ──
                      Form(
                        key: _formKeyDoctor,
                        child: Column(
                          children: [
                            TestId.field('signup_doctor_name_input', TextFormField(
                              controller: _doctorNameCtrl,
                              decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                            )),
                            const SizedBox(height: 12),
                            TestId.field('signup_doctor_specialty_input', TextFormField(
                              controller: _specialtyCtrl,
                              decoration: const InputDecoration(labelText: 'Specialty', border: OutlineInputBorder()),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your specialty' : null,
                            )),
                            const SizedBox(height: 12),
                            TestId.field('signup_doctor_schedule_input', TextFormField(
                              controller: _scheduleCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Schedule (optional)',
                                hintText: 'e.g. Mon-Fri, 9AM-5PM',
                                border: OutlineInputBorder(),
                              ),
                            )),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: TestId.button('signup_doctor_submit_button', FilledButton(
                                onPressed: _loading ? null : _signUpDoctor,
                                child: _loading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Create my account'),
                              ), label: 'Create my account'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;

  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
        ],
      ),
    );
  }
}
