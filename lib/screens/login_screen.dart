import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/doctor.dart';
import 'patient_home_screen.dart';
import 'signup_screen.dart';
import 'admin_home_screen.dart';

/// A friendly, three-tab login screen: Patient, Doctor, or Admin.
///
/// Login rules (kept intentionally simple — this is a testing-target app,
/// not a production hospital system, so there's no password hashing or
/// real auth server involved):
///   • Patients log in with their Patient ID (e.g. PT-0001) + their phone
///     number on file.
///   • Doctors log in with their Doctor ID (e.g. DR-001) + an access code
///     that's just the numeric part of their ID (e.g. "001").
///   • Admin logs in with a fixed username/password (Admin / admin123@).
///
/// TESTABILITY NOTE: every button below uses the pattern
///   Semantics(identifier: ..., explicitChildNodes: false,
///     child: ExcludeSemantics(child: <the real button>))
/// instead of just wrapping the button in a plain Semantics(). Material
/// buttons (FilledButton, TextButton, etc.) create their own internal
/// accessibility node, which was overriding a plain wrapper and leaving
/// the button with no name visible to Appium/Katalon at all. ExcludeSemantics
/// removes the button's own default node from the tree entirely, so our
/// explicit Semantics node — carrying the identifier Katalon needs — is
/// the ONLY one left representing that button.
class LoginScreen extends StatefulWidget {
  final Widget Function(Doctor doctor) onDoctorLogin;

  const LoginScreen({super.key, required this.onDoctorLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _db = DatabaseHelper.instance;

  final _patientIdCtrl = TextEditingController();
  final _patientPhoneCtrl = TextEditingController();
  final _doctorIdCtrl = TextEditingController();
  final _doctorCodeCtrl = TextEditingController();
  final _adminUserCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() => _error = null));
  }

  Future<void> _loginAsPatient() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final patient = await _db.findPatientForLogin(_patientIdCtrl.text, _patientPhoneCtrl.text);
    setState(() => _loading = false);

    if (patient == null) {
      setState(() => _error =
          "We couldn't find an active patient with that ID and phone number. Double-check with the front desk, or ask the admin if your account was deactivated.");
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PatientHomeScreen(patient: patient)),
    );
  }

  Future<void> _loginAsDoctor() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final doctor = await _db.findDoctorForLogin(_doctorIdCtrl.text, _doctorCodeCtrl.text);
    setState(() => _loading = false);

    if (doctor == null) {
      setState(() => _error =
          "That Doctor ID and access code don't match, or this account has been deactivated. Check with your admin.");
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget.onDoctorLogin(doctor)),
    );
  }

  void _loginAsAdmin() {
    setState(() => _error = null);
    const validUsername = 'Admin';
    const validPassword = 'admin123@';

    if (_adminUserCtrl.text.trim() == validUsername && _adminPassCtrl.text == validPassword) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
      );
      return;
    }
    setState(() => _error = 'Incorrect admin username or password.');
  }

  /// Builds a full-width button that exposes a single, clean accessibility
  /// node with [testId] as its identifier — see the class-level doc comment
  /// above for why this is needed instead of a plain Semantics wrapper.
  Widget _testableButton({
    required String testId,
    required String label,
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return Semantics(
      identifier: testId,
      label: label,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      explicitChildNodes: false,
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            key: Key(testId),
            onPressed: onPressed,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('login_screen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_hospital, size: 48, color: Color(0xFF0F6E56)),
                  const SizedBox(height: 12),
                  Text('MedTrack', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Sign in to continue', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 24),
                  TabBar(
                    key: const Key('login_tab_bar'),
                    controller: _tabController,
                    tabs: const [
                      Tab(key: Key('login_tab_patient'), icon: Icon(Icons.person_outline), text: 'Patient'),
                      Tab(key: Key('login_tab_doctor'), icon: Icon(Icons.medical_services_outlined), text: 'Doctor'),
                      Tab(key: Key('login_tab_admin'), icon: Icon(Icons.admin_panel_settings_outlined), text: 'Admin'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Container(
                      key: const Key('login_error_banner'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                        ],
                      ),
                    ),
                  IndexedStack(
                    index: _tabController.index,
                    children: [
                      // ── Patient login ──
                      Column(
                        children: [
                          TextField(
                            key: const Key('login_patient_id_input'),
                            controller: _patientIdCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Patient ID',
                              hintText: 'e.g. PT-0001',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('login_patient_phone_input'),
                            controller: _patientPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone number on file',
                              hintText: 'e.g. 0917 234 5566',
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _testableButton(
                            testId: 'login_patient_submit_button',
                            label: 'Log in as patient',
                            onPressed: _loading ? null : _loginAsPatient,
                            child: _loading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Log in as patient'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Don't have your Patient ID? Ask the front desk.",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      // ── Doctor login ──
                      Column(
                        children: [
                          TextField(
                            key: const Key('login_doctor_id_input'),
                            controller: _doctorIdCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Doctor ID',
                              hintText: 'e.g. DR-001',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('login_doctor_code_input'),
                            controller: _doctorCodeCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Access code',
                              hintText: 'Numeric part of your Doctor ID',
                              prefixIcon: Icon(Icons.lock_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _testableButton(
                            testId: 'login_doctor_submit_button',
                            label: 'Log in as doctor',
                            onPressed: _loading ? null : _loginAsDoctor,
                            child: _loading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Log in as doctor'),
                          ),
                        ],
                      ),
                      // ── Admin login ──
                      Column(
                        children: [
                          TextField(
                            key: const Key('login_admin_username_input'),
                            controller: _adminUserCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('login_admin_password_input'),
                            controller: _adminPassCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _testableButton(
                            testId: 'login_admin_submit_button',
                            label: 'Log in as admin',
                            onPressed: _loginAsAdmin,
                            child: const Text('Log in as admin'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_tabController.index != 2)
                    Semantics(
                      identifier: 'login_go_to_signup_button',
                      label: "Don't have an account? Sign up",
                      button: true,
                      explicitChildNodes: false,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SignupScreen(onDoctorLogin: widget.onDoctorLogin)),
                        );
                      },
                      child: ExcludeSemantics(
                        child: TextButton(
                          key: const Key('login_go_to_signup_button'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SignupScreen(onDoctorLogin: widget.onDoctorLogin)),
                            );
                          },
                          child: const Text("Don't have an account? Sign up"),
                        ),
                      ),
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
