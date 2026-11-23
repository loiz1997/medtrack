# MedTrack — Firestore data model (Firebase alternative)

Use this instead of `supabase_schema.sql` if you choose Firebase over Supabase.
Free tier (Spark plan): 1 GB storage, 50K reads/day, 20K writes/day, free Authentication —
comfortably covers a single clinic's daily volume.

## Collections

```
/patients/{patientId}
  id: string              "PT-0001"
  fullName: string
  age: number
  gender: string
  phone: string
  condition: string
  registeredAt: timestamp
  createdAt: timestamp
  updatedAt: timestamp

/doctors/{doctorId}
  id: string               "DR-001"
  fullName: string
  specialty: string
  schedule: string
  createdAt: timestamp
  updatedAt: timestamp

/transactions/{transactionId}
  id: string                "TX-1001"
  patientId: string          -> references /patients/{patientId}
  patientName: string        (denormalized for fast list rendering)
  doctorId: string           -> references /doctors/{doctorId}
  doctorName: string          (denormalized)
  type: string               "Consultation" | "Follow-up" | ...
  amount: number
  status: string              "Pending" | "Completed" | "Cancelled"
  visitDate: timestamp
  createdAt: timestamp
  updatedAt: timestamp

/staffProfiles/{uid}          (uid = Firebase Auth user id)
  fullName: string
  role: string                "admin" | "doctor" | "receptionist"
  doctorId: string | null     set only when role == "doctor"
  createdAt: timestamp

/auditLog/{logId}
  tableName: string           "patients" | "doctors" | "transactions"
  recordId: string
  action: string               "create" | "update" | "delete"
  performedBy: string          uid
  performedAt: timestamp
  details: map
```

Firestore is a NoSQL document store, so `transactions` denormalizes `patientName` and
`doctorName` directly onto each record — this avoids an extra read per row when rendering
the transaction list, at the cost of needing to update both copies if a patient/doctor is
renamed (rare in practice).

## Security rules (`firestore.rules`)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    match /patients/{patientId} {
      allow read, write: if isSignedIn();
    }

    match /doctors/{doctorId} {
      allow read: if isSignedIn();
      allow write: if isSignedIn(); // restrict to admin role in production
    }

    match /transactions/{txId} {
      allow read, write: if isSignedIn();
    }

    match /staffProfiles/{uid} {
      allow read: if isSignedIn() && request.auth.uid == uid;
      allow write: if false; // managed via admin SDK / Cloud Function only
    }

    match /auditLog/{logId} {
      allow read: if isSignedIn();
      allow write: if false; // written only by Cloud Functions triggers
    }
  }
}
```

## Recommended indexes

Firestore needs composite indexes for compound queries used by the app:

| Collection | Fields | Used by |
|---|---|---|
| transactions | `patientId` asc, `visitDate` desc | Patient detail — visit history |
| transactions | `doctorId` asc, `visitDate` desc | Doctor schedule / revenue report |
| transactions | `status` asc, `visitDate` desc | Dashboard — pending transactions |
| patients | `fullName` asc | Alphabetical patient list |

Firestore will prompt you with a direct console link to create each index the first time
a query needs it — click through rather than pre-creating all of them manually.

## Choosing between this and Supabase

| | Supabase | Firebase/Firestore |
|---|---|---|
| Data model | Relational (SQL), foreign keys enforced | Document store, denormalized |
| Offline-first sync | Manual (pair with local SQLite) | Built-in offline persistence |
| Best fit here | If you want strict data integrity (e.g. a transaction can't reference a deleted patient) | If you want less sync code to write yourself |

Both are free at this clinic's scale. The Flutter scaffold in `medtrack_flutter/` ships
with a `SyncService` interface so you can implement either backend without touching the
UI or local database code.
