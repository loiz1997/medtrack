import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../models/clinic_transaction.dart';
import '../models/patient.dart';
import '../models/doctor.dart';
import '../widgets/test_id.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _db = DatabaseHelper.instance;
  List<ClinicTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await _db.getTransactions();
    setState(() => _transactions = results);
  }

  Future<void> _openLogSheet() async {
    final patients = await _db.getPatients();
    final doctors = await _db.getDoctors();
    if (patients.isEmpty || doctors.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Register at least one patient and doctor first')));
      }
      return;
    }

    Patient? selectedPatient;
    Doctor? selectedDoctor;
    final typeCtrl = TextEditingController(text: 'Consultation');
    final amountCtrl = TextEditingController();

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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Log transaction', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                TestId.field('admin_log_transaction_patient_dropdown', DropdownButtonFormField<Patient>(
                  decoration: const InputDecoration(labelText: 'Patient'),
                  items: patients
                      .map((p) => DropdownMenuItem(value: p, child: Text('${p.fullName} (${p.id})')))
                      .toList(),
                  onChanged: (v) => setSheetState(() => selectedPatient = v),
                )),
                const SizedBox(height: 12),
                TestId.field('admin_log_transaction_doctor_dropdown', DropdownButtonFormField<Doctor>(
                  decoration: const InputDecoration(labelText: 'Doctor'),
                  items: doctors.map((d) => DropdownMenuItem(value: d, child: Text(d.fullName))).toList(),
                  onChanged: (v) => setSheetState(() => selectedDoctor = v),
                )),
                const SizedBox(height: 12),
                TestId.field('admin_log_transaction_type_input', TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Transaction type'))),
                const SizedBox(height: 12),
                TestId.field('admin_log_transaction_amount_input', TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (₱)'),
                )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TestId.button('admin_log_transaction_submit_button', FilledButton(
                    onPressed: () async {
                      if (selectedPatient == null || selectedDoctor == null) return;
                      final id = await _db.nextTransactionId();
                      await _db.insertTransaction(ClinicTransaction(
                        id: id,
                        patientId: selectedPatient!.id,
                        patientName: selectedPatient!.fullName,
                        doctorId: selectedDoctor!.id,
                        doctorName: selectedDoctor!.fullName,
                        type: typeCtrl.text.trim().isEmpty ? 'Consultation' : typeCtrl.text.trim(),
                        amount: double.tryParse(amountCtrl.text) ?? 0,
                        status: TxStatus.pending,
                        visitDate: DateTime.now(),
                      ));
                      SyncService.instance.syncAll();
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                    child: const Text('Log transaction'),
                  ), label: 'Log transaction'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approve(String id) async {
    await _db.updateTransactionStatus(id, TxStatus.completed);
    SyncService.instance.syncAll();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction approved and marked Completed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('admin_transactions_screen'),
      appBar: AppBar(title: const Text('Transactions'), centerTitle: false),
      floatingActionButton: TestId.button('admin_log_transaction_fab', FloatingActionButton.extended(
        key: const Key('admin_log_transaction_fab'),
        onPressed: _openLogSheet,
        icon: const Icon(Icons.add),
        label: const Text('Log transaction'),
      ), label: 'Log transaction'),
      body: _transactions.isEmpty
          ? const Center(child: Text('No transactions logged yet'))
          : TestId.group('admin_transactions_list', ListView.builder(
              key: const Key('admin_transactions_list'),
              padding: const EdgeInsets.all(12),
              itemCount: _transactions.length,
              itemBuilder: (context, i) {
                final t = _transactions[i];
                final completed = t.status == TxStatus.completed;
                return TestId.group('admin_transaction_row_${t.id}', Card(
                  key: Key('admin_transaction_row_${t.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(t.patientName),
                    subtitle: Text('${t.type} · ${t.doctorName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₱${t.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Chip(
                              label: Text(t.status.label, style: const TextStyle(fontSize: 11, color: Colors.white)),
                              backgroundColor: Color(t.status.colorValue),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        if (!completed) ...[
                          const SizedBox(width: 8),
                          TestId.button('admin_approve_transaction_${t.id}', IconButton(
                            key: Key('admin_approve_transaction_${t.id}'),
                            icon: const Icon(Icons.check_circle_outline),
                            color: Colors.green,
                            tooltip: 'Mark completed',
                            onPressed: () => _approve(t.id),
                          ), label: 'Mark completed'),
                        ],
                      ],
                    ),
                  ),
                ));
              },
            )),
    );
  }
}
