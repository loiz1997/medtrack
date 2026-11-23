import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../models/clinic_transaction.dart';
import 'all_patients_by_doctor_screen.dart';
import 'active_doctors_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final result = await SyncService.instance.syncAll();
    setState(() => _syncing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), duration: const Duration(seconds: 6)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseHelper.instance;

    return Scaffold(
      key: const Key('admin_dashboard_screen'),
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: false,
        actions: [
          IconButton(
            key: const Key('admin_sync_now_button'),
            icon: _syncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Sync now',
            onPressed: _syncing ? null : _syncNow,
          ),
        ],
      ),
      body: FutureBuilder(
        future: Future.wait([db.getPatients(), db.getActiveDoctors(), db.getTransactions()]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final patients = snapshot.data![0] as List;
          final activeDoctors = snapshot.data![1] as List;
          final transactions = snapshot.data![2] as List<ClinicTransaction>;

          final pending = transactions.where((t) => t.status == TxStatus.pending).length;
          final todayRevenue = transactions
              .where((t) => _isToday(t.visitDate))
              .fold<double>(0, (sum, t) => sum + t.amount);

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
                  _StatCard(
                    key: const Key('admin_dashboard_total_patients_card'),
                    label: 'Total patients',
                    value: '${patients.length}',
                    icon: Icons.people_outline,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AllPatientsByDoctorScreen()),
                    ),
                  ),
                  _StatCard(
                    key: const Key('admin_dashboard_active_doctors_card'),
                    label: 'Active doctors',
                    value: '${activeDoctors.length}',
                    icon: Icons.medical_services_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ActiveDoctorsScreen()),
                    ),
                  ),
                  _StatCard(
                    key: const Key('admin_dashboard_pending_card'),
                    label: 'Pending transactions',
                    value: '$pending',
                    icon: Icons.schedule,
                    color: Colors.orange,
                  ),
                  _StatCard(
                    key: const Key('admin_dashboard_revenue_card'),
                    label: "Today's revenue",
                    value: '₱${todayRevenue.toStringAsFixed(0)}',
                    icon: Icons.trending_up,
                    color: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Recent transactions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...transactions.take(5).map((t) => Card(
                    key: Key('admin_recent_transaction_${t.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(t.patientName),
                      subtitle: Text('${t.type} · ${t.doctorName}'),
                      trailing: Chip(
                        label: Text(t.status.label, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        backgroundColor: Color(t.status.colorValue),
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
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
