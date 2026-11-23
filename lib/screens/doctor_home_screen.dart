import 'package:flutter/material.dart';
import '../models/doctor.dart';
import 'doctor_dashboard_screen.dart';
import 'doctor_patients_screen.dart';
import 'doctor_appointments_screen.dart';
import 'login_screen.dart';

/// The doctor's own app experience — deliberately smaller than the admin's:
/// no "add patient" or "add doctor" buttons anywhere, and no Doctors tab
/// at all, since a doctor manages their own patients and appointments only.
class DoctorHomeScreen extends StatefulWidget {
  final Doctor doctor;

  const DoctorHomeScreen({super.key, required this.doctor});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _index = 0;

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(onDoctorLogin: (doctor) => DoctorHomeScreen(doctor: doctor))),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DoctorDashboardScreen(doctor: widget.doctor),
      DoctorPatientsScreen(doctor: widget.doctor),
      DoctorAppointmentsScreen(doctor: widget.doctor),
    ];

    const destinations = [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
      NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'My Patients'),
      NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Appointments'),
    ];

    final isWide = MediaQuery.of(context).size.width >= 800;
    final logoutButton = IconButton(
      key: const Key('doctor_logout_button'),
      icon: const Icon(Icons.logout),
      tooltip: 'Log out',
      onPressed: _logout,
    );

    if (isWide) {
      return Scaffold(
        key: const Key('doctor_home_screen'),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(children: [const Icon(Icons.local_hospital, size: 28), const SizedBox(height: 8), logoutButton]),
              ),
              destinations: destinations
                  .map((d) => NavigationRailDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: Text(d.label)))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: screens[_index]),
          ],
        ),
      );
    }

    return Scaffold(
      key: const Key('doctor_home_screen'),
      appBar: AppBar(title: Text('Hi, ${widget.doctor.fullName}'), actions: [logoutButton]),
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        key: const Key('doctor_bottom_nav'),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
