# MedTrack — Flutter project

A clinic patient/doctor registration and transaction app, replacing manual Excel sheets.
Runs on iOS and Windows from a single codebase, using an entirely free tool/package stack.

## Stack

- **Flutter** — UI framework, one codebase for iOS + Windows
- **sqflite** / **sqflite_common_ffi** — local, offline-first storage (works with zero internet)
- **supabase_flutter** — free-tier cloud sync (swap for `cloud_firestore` if you prefer Firebase — see `lib/services/sync_service.dart`)
- **csv** + **file_picker** — Excel migration (import existing `.csv` exports)
- **provider** — lightweight state management

None of these require a paid license. See the cost breakdown at the bottom.

## Project structure

```
lib/
  models/              Patient, Doctor, ClinicTransaction — plain Dart data classes
  services/
    database_helper.dart   SQLite schema + queries (source of truth on-device)
    sync_service.dart      Pushes local changes to Supabase/Firebase when online
  screens/
    dashboard_screen.dart
    patients_screen.dart   Search, register, and CSV import
    doctors_screen.dart
    transactions_screen.dart
  main.dart              Responsive shell: side rail on Windows, bottom nav on iOS
```

## Getting started

1. Install the Flutter SDK: https://docs.flutter.dev/get-started/install (free)
2. `flutter pub get`
3. Run on Windows: `flutter run -d windows` (requires "Desktop development with C++" workload in Visual Studio — Community edition is free)
4. Run on iOS: `flutter run -d <simulator-or-device>` (requires Xcode, free from the Mac App Store; a physical-device build needs a Mac)

## Connecting the free cloud backend

The app works fully offline with zero setup — SQLite handles everything locally.
To add multi-device sync:

1. Create a free Supabase project at https://supabase.com (500 MB DB, no card required)
2. Run `backend/supabase_schema.sql` (in the project root, one level up) in the Supabase SQL editor
3. Uncomment the `SyncService.initSupabase(...)` call in `main.dart` and pass your project URL + anon key
4. Call `SyncService.instance.syncAll()` whenever you want to push local changes up (e.g. on app resume)

Prefer Firebase instead? See `backend/firestore_schema.md` for the equivalent Firestore
collections and security rules — `sync_service.dart` is written as a thin wrapper so you
can swap the Supabase calls for `cloud_firestore` calls without touching any screen code.

## Migrating your existing Excel sheet

On the Patients screen, tap the import icon and pick a `.csv` file exported from Excel
(File > Save As > CSV in Excel) with these columns: `name, age, gender, phone, condition`.
Each row becomes a new patient record with an auto-generated ID.

## Cost breakdown

| Item | Cost |
|---|---|
| Flutter SDK, Dart, VS Code | Free |
| All packages in `pubspec.yaml` | Free, open-source |
| SQLite local storage | Free, no limits |
| Supabase or Firebase free tier | Free at this scale |
| Testing on iOS Simulator / Windows desktop | Free |
| Publishing to the Apple App Store | $99/year (only if you want public App Store distribution) |
| Distributing a Windows `.exe` directly (no Store) | Free |
