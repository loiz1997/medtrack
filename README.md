# MedTrack

A cross-platform clinic app (Android and iOS) built with Flutter. Patients book appointments, doctors respond to them, and an admin keeps the clinic's records in order. It works offline and syncs to the cloud when a connection is available.

I built MedTrack as a realistic **test target for mobile test automation** with Katalon Studio and Appium, so it also includes a full manual test suite and a unique test ID scheme for UI elements.

> **Demo project.** All patients, doctors and transactions in this repo are fictional sample data. Don't store real patient information in it.

📄 **Full documentation with every screen:** [docs/MedTrack_Documentation.pdf](docs/MedTrack_Documentation.pdf)

---

## Features

| Role | What they can do |
|---|---|
| **Patient** | Sign up, log in with Patient ID + phone number, book an appointment with an active doctor, follow the status of each request, edit their profile |
| **Doctor** | Sign up, log in with Doctor ID + access code, see a dashboard with live counters, view their patients, accept / decline / complete appointments |
| **Admin** | Log in with a username and password, see clinic-wide stats and recent transactions, switch patient and doctor accounts Active / Inactive, filter transactions by status, export patient records as CSV |

Other behaviour worth knowing:

- Inactive patients and doctors are blocked at login, and inactive doctors can't be booked.
- Every appointment is a transaction with one of four statuses: **Pending → Accepted → Completed**, or **Declined**.
- Doctor access code is the numeric part of the Doctor ID (for example `DR-001` → `001`).

## Tech stack (all free)

- **Flutter / Dart**, Material 3
- **SQLite** on the device (`sqflite`) for offline-first storage
- **Supabase** (free tier) for cloud sync: changes are pushed after they happen, and the latest data is pulled when the app starts
- **Katalon Studio + Appium** (XCUITest on iOS, UiAutomator2 on Android) for test automation

## Project structure

```
lib/
  config/        Supabase settings (secrets.example.dart is a template)
  models/        Patient, doctor and transaction models
  screens/       Login, sign-up, and patient / doctor / admin screens
  services/      Local database helper and Supabase sync service
  widgets/       Shared UI widgets
backend/         SQL for the Supabase tables
docs/            Product documentation (PDF)
```

## Getting started

### 1. Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- For iOS: Xcode and CocoaPods
- For Android: Android Studio with an emulator (Android SDK API 36, and Java 17 or newer for Gradle)
- A free [Supabase](https://supabase.com) account

### 2. Set up Supabase

1. Create a new Supabase project.
2. In the SQL Editor, run the SQL files in the `backend/` folder: the schema first, then the migration file.
3. In **Project Settings → API**, copy your **Project URL** and **anon public key**.

### 3. Add your keys

The real keys are intentionally **not** in this repository. Copy the template and fill it in:

```bash
cp lib/config/secrets.example.dart lib/config/secrets.dart
```

Then open `lib/config/secrets.dart` and replace the placeholders with your own Project URL and anon key. This file is listed in `.gitignore`, so it will never be committed.

### 4. Run the app

```bash
flutter pub get
flutter run
```

On iOS, run `pod install` inside the `ios` folder first if Flutter asks for it.

## Demo login

| Role | ID / username | Secret |
|---|---|---|
| Admin | `Admin` | `admin123@` |

The admin password is a **demo credential only**. Patients and doctors are created from the **Sign up** screen. After signing up, the app shows the new ID (and a doctor's access code) to log in with.

## Test automation

MedTrack was built to be easy to automate.

- **Test IDs:** UI elements follow a naming pattern such as `login_patient_id_input`, `login_admin_submit_button` and `admin_patient_active_toggle_PT-001`. In Flutter these are published with `Semantics(identifier: ...)`, because Appium can't see a Flutter `Key`. The login screen already uses them, and I'm rolling the same change out to the remaining screens.
- **Manual test suite:** 60 test cases across the patient, doctor and admin modules (happy path, negative and edge cases, tagged smoke / sanity / regression) in [docs/MedTrack_Test_Cases.xlsx](docs/MedTrack_Test_Cases.xlsx).
- **Targets tested:** iOS Simulator, a real iPhone, and an Android emulator.

## Known setup notes

A few packages are pinned because newer versions broke the build:

- `file_picker` 8.1.2 (needs `compileSdk` 36 on Android)
- `csv` 6.0.0
- `share_plus` ^12.0.2

On Android, Gradle needs Java 17 or newer. If Gradle ignores a fix, run `./gradlew --stop` and `./gradlew clean` inside the `android` folder.

## Status

This is a portfolio and testing project. Planned next steps: unique test IDs on every screen, row-level security rules for Supabase that match each role, and screenshots in this README.
