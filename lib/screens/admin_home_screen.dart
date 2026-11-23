import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'patients_screen.dart';
import 'doctors_screen.dart';
import 'transactions_screen.dart';
import 'login_screen.dart';
import '../widgets/test_id.dart';

/// The admin's own app experience. Admin is the only account that can turn
/// a patient or doctor account active/inactive (via the Switch on each row
/// in PatientsScreen / DoctorsScreen). Login is a fixed username/password
/// (Admin / admin123@) checked directly in LoginScreen — see the doc
/// comment there for why this app doesn't use full server-side auth.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    PatientsScreen(),
    DoctorsScreen(),
    TransactionsScreen(),
  ];

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
    NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Patients'),
    NavigationDestination(icon: Icon(Icons.medical_services_outlined), selectedIcon: Icon(Icons.medical_services), label: 'Doctors'),
    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transactions'),
  ];

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(onDoctorLogin: (_) => const SizedBox())),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final logoutButton = TestId.button('admin_logout_button', IconButton(
      key: const Key('admin_logout_button'),
      icon: const Icon(Icons.logout),
      tooltip: 'Log out',
      onPressed: _logout,
    ), label: 'Log out');

    if (isWide) {
      return Scaffold(
        key: const Key('admin_home_screen'),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(children: [
                  const Icon(Icons.admin_panel_settings, size: 28),
                  const SizedBox(height: 8),
                  logoutButton,
                ]),
              ),
              destinations: _destinations
                  .map((d) => NavigationRailDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: Text(d.label)))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _screens[_index]),
          ],
        ),
      );
    }

    return Scaffold(
      key: const Key('admin_home_screen'),
      appBar: AppBar(title: const Text('Admin'), actions: [logoutButton]),
      body: _screens[_index],
      bottomNavigationBar: TestId.group('admin_bottom_nav', NavigationBar(
        key: const Key('admin_bottom_nav'),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            TestId.group('admin_nav_${d.label.toLowerCase().replaceAll(' ', '_')}_tab', d),
        ],
      )),
    );
  }
}
