import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/patient.dart';
import '../models/doctor.dart';
import '../models/clinic_transaction.dart';

/// Local, offline-first storage. This is the on-device source of truth for
/// the UI; SyncService pushes local changes up to Supabase, and pulls
/// existing cloud records back down at app startup (see SyncService.pullAll)
/// so test data survives across fresh app installs/Katalon test runs.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'medtrack.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE patients (
            id TEXT PRIMARY KEY,
            full_name TEXT NOT NULL,
            age INTEGER,
            gender TEXT,
            phone TEXT NOT NULL,
            condition TEXT,
            registered_at TEXT NOT NULL,
            photo_path TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            status TEXT NOT NULL DEFAULT 'active',
            dirty INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE doctors (
            id TEXT PRIMARY KEY,
            full_name TEXT NOT NULL,
            specialty TEXT NOT NULL,
            schedule TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            status TEXT NOT NULL DEFAULT 'active',
            dirty INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            patient_id TEXT NOT NULL,
            patient_name TEXT NOT NULL,
            doctor_id TEXT NOT NULL,
            doctor_name TEXT NOT NULL,
            type TEXT NOT NULL,
            amount REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'Pending',
            visit_date TEXT NOT NULL,
            dirty INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY (patient_id) REFERENCES patients (id),
            FOREIGN KEY (doctor_id) REFERENCES doctors (id)
          )
        ''');
        await db.execute('''
          CREATE TABLE audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,
            record_id TEXT NOT NULL,
            action TEXT NOT NULL,
            performed_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE patients ADD COLUMN photo_path TEXT');
          await db.execute('ALTER TABLE patients ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
          await db.execute('ALTER TABLE doctors ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE patients ADD COLUMN status TEXT NOT NULL DEFAULT 'active'");
          await db.execute("ALTER TABLE doctors ADD COLUMN status TEXT NOT NULL DEFAULT 'active'");
          await db.execute("UPDATE patients SET status = CASE WHEN is_active = 1 THEN 'active' ELSE 'inactive' END");
          await db.execute("UPDATE doctors SET status = CASE WHEN is_active = 1 THEN 'active' ELSE 'inactive' END");
        }
      },
    );
  }

  // ── Patients ──────────────────────────────────────────
  Future<List<Patient>> getPatients({String query = ''}) async {
    final db = await database;
    final rows = query.isEmpty
        ? await db.query('patients', orderBy: 'registered_at DESC')
        : await db.query(
            'patients',
            where: 'full_name LIKE ? OR id LIKE ? OR condition LIKE ?',
            whereArgs: ['%$query%', '%$query%', '%$query%'],
            orderBy: 'registered_at DESC',
          );
    return rows.map((r) => Patient.fromMap(r)).toList();
  }

  Future<String> nextPatientId() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM patients')) ?? 0;
    return 'PT-${(count + 1).toString().padLeft(4, '0')}';
  }

  Future<void> insertPatient(Patient p) async {
    final db = await database;
    await db.insert('patients', p.toMap()..['dirty'] = 1);
    await _log('patients', p.id, 'INSERT');
  }

  /// Admin-only: turn a patient account on/off.
  Future<void> setPatientActive(String id, bool active) async {
    final db = await database;
    await db.update(
      'patients',
      {'is_active': active ? 1 : 0, 'status': active ? 'active' : 'inactive', 'dirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _log('patients', id, 'UPDATE');
  }

  Future<Patient?> findPatientForLogin(String patientId, String phone) async {
    final db = await database;
    final rows = await db.query(
      'patients',
      where: 'id = ? AND phone = ? AND is_active = 1',
      whereArgs: [patientId.trim(), phone.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Patient.fromMap(rows.first);
  }

  /// Used by the patient's Edit Profile screen — updates name, age, gender,
  /// phone, and photo. Does not touch id, condition, or registered_at.
  Future<void> updatePatientProfile(Patient p) async {
    final db = await database;
    await db.update(
      'patients',
      {
        'full_name': p.fullName,
        'age': p.age,
        'gender': p.gender,
        'phone': p.phone,
        'photo_path': p.photoPath,
        'dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [p.id],
    );
    await _log('patients', p.id, 'UPDATE');
  }

  // ── Doctors ───────────────────────────────────────────
  Future<List<Doctor>> getDoctors() async {
    final db = await database;
    final rows = await db.query('doctors', orderBy: 'full_name ASC');
    return rows.map((r) => Doctor.fromMap(r)).toList();
  }

  Future<String> nextDoctorId() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM doctors')) ?? 0;
    return 'DR-${(count + 1).toString().padLeft(3, '0')}';
  }

  Future<void> insertDoctor(Doctor d) async {
    final db = await database;
    await db.insert('doctors', d.toMap()..['dirty'] = 1);
    await _log('doctors', d.id, 'INSERT');
  }

  /// Admin-only: turn a doctor account on/off.
  Future<void> setDoctorActive(String id, bool active) async {
    final db = await database;
    await db.update(
      'doctors',
      {'is_active': active ? 1 : 0, 'status': active ? 'active' : 'inactive', 'dirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _log('doctors', id, 'UPDATE');
  }

  Future<Doctor?> findDoctorForLogin(String doctorId, String accessCode) async {
    final db = await database;
    final rows = await db.query(
      'doctors',
      where: 'id = ? AND is_active = 1',
      whereArgs: [doctorId.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final expectedCode = doctorId.trim().split('-').last;
    if (accessCode.trim() != expectedCode) return null;
    return Doctor.fromMap(rows.first);
  }

  /// Used by the Doctor dashboard's clickable "Active doctors" widget, and
  /// by the appointment-booking screen (patients can only book with
  /// doctors who are currently active).
  Future<List<Doctor>> getActiveDoctors() async {
    final db = await database;
    final rows = await db.query('doctors', where: 'is_active = 1', orderBy: 'full_name ASC');
    return rows.map((r) => Doctor.fromMap(r)).toList();
  }

  /// Used by the "My Patients" screen — a doctor should only see patients
  /// who have at least one appointment/transaction with them.
  Future<List<Patient>> getPatientsForDoctor(String doctorId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT p.* FROM patients p
      INNER JOIN transactions t ON t.patient_id = p.id
      WHERE t.doctor_id = ?
      ORDER BY p.full_name ASC
    ''', [doctorId]);
    return rows.map((r) => Patient.fromMap(r)).toList();
  }

  // ── Transactions ──────────────────────────────────────
  Future<List<ClinicTransaction>> getTransactions({String? patientId, String? doctorId}) async {
    final db = await database;
    if (patientId != null) {
      final rows = await db.query('transactions', where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'visit_date DESC');
      return rows.map((r) => ClinicTransaction.fromMap(r)).toList();
    }
    if (doctorId != null) {
      final rows = await db.query('transactions', where: 'doctor_id = ?', whereArgs: [doctorId], orderBy: 'visit_date DESC');
      return rows.map((r) => ClinicTransaction.fromMap(r)).toList();
    }
    final rows = await db.query('transactions', orderBy: 'visit_date DESC');
    return rows.map((r) => ClinicTransaction.fromMap(r)).toList();
  }

  Future<String> nextTransactionId() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transactions')) ?? 0;
    return 'TX-${1000 + count + 1}';
  }

  Future<void> insertTransaction(ClinicTransaction t) async {
    final db = await database;
    await db.insert('transactions', t.toMap()..['dirty'] = 1);
    await _log('transactions', t.id, 'INSERT');
  }

  Future<void> updateTransactionStatus(String id, TxStatus status) async {
    final db = await database;
    await db.update(
      'transactions',
      {'status': status.label, 'dirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _log('transactions', id, 'UPDATE');
  }

  // ── Sync helpers ──────────────────────────────────────
  /// Records not yet pushed to the cloud backend (used by SyncService.syncAll).
  Future<List<Map<String, dynamic>>> getDirtyRows(String table) async {
    final db = await database;
    return db.query(table, where: 'dirty = 1');
  }

  Future<void> markSynced(String table, String id) async {
    final db = await database;
    await db.update(table, {'dirty': 0}, where: 'id = ?', whereArgs: [id]);
  }

  /// Writes a record that came FROM the cloud into the local database
  /// (used by SyncService.pullAll, at app startup). Marked dirty = 0 since
  /// it's already exactly what's in the cloud — no need to push it back.
  /// Uses REPLACE so this works whether the record already exists locally
  /// (keeps it up to date) or doesn't exist yet (restores it).
  Future<void> upsertFromCloud(String table, Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(
      table,
      {...row, 'dirty': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _log(String table, String recordId, String action) async {
    final db = await database;
    await db.insert('audit_log', {
      'table_name': table,
      'record_id': recordId,
      'action': action,
      'performed_at': DateTime.now().toIso8601String(),
    });
  }
}
