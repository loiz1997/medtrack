import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';

/// Keeps the on-device database and the Supabase cloud database in sync,
/// in BOTH directions:
///
///   • syncAll()  — pushes local changes UP to the cloud (called after
///     every sign-up, booking, status change, etc.)
///   • pullAll()  — pulls existing cloud records DOWN to the device
///     (called once, at app startup)
///
/// Why pullAll() matters for testing: each time Katalon launches a fresh
/// copy of the app on the Simulator, the local database starts completely
/// empty — it's a brand-new install. Without pulling from the cloud first,
/// every patient/doctor created in a *previous* test run would be "lost"
/// on the next run, forcing you to recreate test data every time. Calling
/// pullAll() at startup restores everything that was ever successfully
/// synced up to Supabase, so test data survives across runs automatically.
class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  final _db = DatabaseHelper.instance;

  SupabaseClient get _client => Supabase.instance.client;

  // ── Push: local changes -> cloud ─────────────────────────
  Future<String> syncAll() async {
    final patientResult = await _pushTable('patients');
    final doctorResult = await _pushTable('doctors');
    final txResult = await _pushTable('transactions');
    final problems = [patientResult, doctorResult, txResult].where((r) => r.isNotEmpty).toList();
    if (problems.isEmpty) return 'All caught up — everything is synced.';
    return problems.join('\n');
  }

  Future<String> _pushTable(String table) async {
    final dirtyRows = await _db.getDirtyRows(table);
    if (dirtyRows.isEmpty) return '';

    int failCount = 0;
    String? lastError;

    for (final row in dirtyRows) {
      final payload = Map<String, dynamic>.from(row)..remove('dirty');
      try {
        await _client.from(table).upsert(payload);
        await _db.markSynced(table, row['id'] as String);
      } catch (e) {
        failCount++;
        lastError = e.toString();
      }
    }

    if (failCount > 0) {
      return '$table: $failCount not synced — $lastError';
    }
    return '';
  }

  // ── Pull: cloud records -> local device ──────────────────
  /// Call this once at app startup, right after initSupabase(). Restores
  /// every patient, doctor, and transaction that has ever been successfully
  /// synced to the cloud, so test data created in earlier app runs/installs
  /// is available immediately — no need to recreate it by hand.
  Future<void> pullAll() async {
    await _pullTable(
      'patients',
      ['id', 'full_name', 'age', 'gender', 'phone', 'condition', 'registered_at', 'photo_path', 'is_active', 'status'],
    );
    await _pullTable(
      'doctors',
      ['id', 'full_name', 'specialty', 'schedule', 'is_active', 'status'],
    );
    await _pullTable(
      'transactions',
      ['id', 'patient_id', 'patient_name', 'doctor_id', 'doctor_name', 'type', 'amount', 'status', 'visit_date'],
    );
  }

  Future<void> _pullTable(String table, List<String> columns) async {
    try {
      final rows = await _client.from(table).select(columns.join(','));
      for (final row in rows) {
        await _db.upsertFromCloud(table, Map<String, dynamic>.from(row));
      }
    } catch (_) {
      // No internet, or this is the very first run before anything has
      // ever been synced — safe to skip. Whatever's already stored
      // locally (if anything) is used as-is; nothing is lost by this.
    }
  }

  /// Call once at app startup, after Supabase.initialize() in main.dart.
  static Future<void> initSupabase({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}
