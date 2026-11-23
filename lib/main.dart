import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/doctor_home_screen.dart';
import 'services/sync_service.dart';
import 'config/secrets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Connects to the free Supabase cloud database. See backend/supabase_schema.sql
  // and the admin_and_patient_features_migration.sql that came with this
  // update for the matching cloud table setup.
  await SyncService.initSupabase(
    url: Secrets.supabaseUrl,
    anonKey:
        Secrets.supabaseAnonKey,
  );
await SyncService.instance.pullAll();

  runApp(const MedTrackApp());
}

class MedTrackApp extends StatelessWidget {
  const MedTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0F6E56), // teal-700, matches the prototype
        scaffoldBackgroundColor: const Color(0xFFFAFAF9),
      ),
      // The app opens on the login screen, which has three tabs: Patient,
      // Doctor, and Admin.
      //   • Patients land in PatientHomeScreen (wired inside login_screen.dart)
      //   • Doctors land in DoctorHomeScreen — their own smaller app, with
      //     no "add patient"/"add doctor" buttons anywhere
      //   • Admin lands in AdminHomeScreen (wired inside login_screen.dart) —
      //     the only account that can activate/deactivate patient and
      //     doctor accounts
      home: LoginScreen(onDoctorLogin: (doctor) => DoctorHomeScreen(doctor: doctor)),
    );
  }
}
