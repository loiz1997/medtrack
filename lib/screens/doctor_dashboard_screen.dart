import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../models/clinic_transaction.dart';
import '../services/database_helper.dart';
import 'all_patients_by_doctor_screen.dart';
import 'active_doctors_screen.dart';
import '../widgets/test_id.dart';

/// The doctor's own dashboard. "Total patients" and "Active doctors" are
/// clinic-wide overview numbers, and both are tappable — they open a
/// drill-down list, same idea as the admin dashboard.
class DoctorDashboardScreen extends StatefulWidget {
  final Doctor doctor;

  const DoctorDashboardScreen({super.key, required this.doctor});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final _db = DatabaseHelper.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('doctor_dashboard_screen'),
      appBar: AppBar(title: const Text('Dashboard'), centerTitle: false),
      body: FutureBuilder(
        future: Future.wait([
          _db.getPatients(),
          _db.getActiveDoctors(),
          _db.getTransactions(doctorId: widget.doctor.id),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final totalPatients = (snapshot.data![0] as List).length;
          final activeDoctors = (snapshot.data![1] as List).length;
          final myAppointments = snapshot.data![2] as List<ClinicTransaction>;
          final pending = myAppointments.where((t) => t.status == TxStatus.pending).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  TestId.group('doctor_dashboard_total_patients_card', _StatCard(
                    key: const Key('doctor_dashboard_total_patients_card'),
                    label: 'Total patients',
                    value: '$totalPatients',
                    icon: Icons.people_outline,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AllPatientsByDoctorScreen()),
                    ),
                  )),
                  TestId.group('doctor_dashboard_active_doctors_card', _StatCard(
                    key: const Key('doctor_dashboard_active_doctors_card'),
                    label: 'Active doctors',
                    value: '$activeDoctors',
                    icon: Icons.medical_services_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ActiveDoctorsScreen()),
                    ),
                  )),
                  TestId.group('doctor_dashboard_pending_card', _StatCard(
                    key: const Key('doctor_dashboard_pending_card'),
                    label: 'My pending requests',
                    value: '$pending',
                    icon: Icons.schedule,
                    color: Colors.orange,
                  )),
                  TestId.group('doctor_dashboard_my_appointments_card', _StatCard(
                    key: const Key('doctor_dashboard_my_appointments_card'),
                    label: 'My total appointments',
                    value: '${myAppointments.length}',
                    icon: Icons.event_note_outlined,
                    color: Colors.teal,
                  )),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const _StatCard({super.key, required this.label, required this.value, required this.icon, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 18, color: Colors.grey.shade600),
                  if (onTap != null) Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                ],
              ),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
