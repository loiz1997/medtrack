-- MedTrack — Supabase (Postgres) schema
-- Free tier: 500 MB database, 50K monthly active users — comfortably covers a single clinic.
-- Run this in the Supabase SQL editor (Project > SQL Editor > New query).

create extension if not exists "uuid-ossp";

-- ─────────────────────────────────────────────
-- DOCTORS
-- ─────────────────────────────────────────────
create table doctors (
  id            text primary key,          -- e.g. 'DR-001'
  full_name     text not null,
  specialty     text not null,
  schedule      text,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- ─────────────────────────────────────────────
-- PATIENTS
-- ─────────────────────────────────────────────
create table patients (
  id            text primary key,          -- e.g. 'PT-0001'
  full_name     text not null,
  age           int,
  gender        text,
  phone         text not null,
  condition     text,
  registered_at date default current_date,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create index idx_patients_name on patients using gin (to_tsvector('simple', full_name));

-- ─────────────────────────────────────────────
-- TRANSACTIONS  (consultations, follow-ups, billing entries)
-- ─────────────────────────────────────────────
create table transactions (
  id            text primary key,          -- e.g. 'TX-1001'
  patient_id    text not null references patients(id) on delete cascade,
  doctor_id     text not null references doctors(id) on delete restrict,
  type          text not null,             -- 'Consultation', 'Follow-up', etc.
  amount        numeric(10,2) not null default 0,
  status        text not null default 'Pending' check (status in ('Pending','Completed','Cancelled')),
  visit_date    date not null default current_date,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create index idx_transactions_patient on transactions(patient_id);
create index idx_transactions_doctor on transactions(doctor_id);
create index idx_transactions_date on transactions(visit_date);

-- ─────────────────────────────────────────────
-- AUDIT LOG  (who registered/edited/deleted a record, and when)
-- ─────────────────────────────────────────────
create table audit_log (
  id            uuid primary key default uuid_generate_v4(),
  table_name    text not null,
  record_id     text not null,
  action        text not null check (action in ('INSERT','UPDATE','DELETE')),
  performed_by  uuid references auth.users(id),
  performed_at  timestamptz default now(),
  details       jsonb
);

-- ─────────────────────────────────────────────
-- STAFF ROLES  (Admin, Doctor, Receptionist)
-- ─────────────────────────────────────────────
create table staff_profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  full_name     text not null,
  role          text not null check (role in ('admin','doctor','receptionist')),
  doctor_id     text references doctors(id),   -- set only if role = 'doctor'
  created_at    timestamptz default now()
);

-- ─────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ─────────────────────────────────────────────
alter table patients enable row level security;
alter table doctors enable row level security;
alter table transactions enable row level security;
alter table staff_profiles enable row level security;

-- Any authenticated staff member can read/write patients & transactions
create policy "staff can read patients" on patients for select
  using (auth.role() = 'authenticated');
create policy "staff can write patients" on patients for insert
  with check (auth.role() = 'authenticated');
create policy "staff can update patients" on patients for update
  using (auth.role() = 'authenticated');

create policy "staff can read doctors" on doctors for select
  using (auth.role() = 'authenticated');

create policy "staff can read transactions" on transactions for select
  using (auth.role() = 'authenticated');
create policy "staff can write transactions" on transactions for insert
  with check (auth.role() = 'authenticated');

-- Doctors can only see their own profile row; admins see all (simplified — expand as needed)
create policy "staff can read own profile" on staff_profiles for select
  using (auth.uid() = id);

-- ─────────────────────────────────────────────
-- updated_at auto-touch trigger
-- ─────────────────────────────────────────────
create or replace function touch_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_patients_updated before update on patients
  for each row execute function touch_updated_at();
create trigger trg_doctors_updated before update on doctors
  for each row execute function touch_updated_at();
create trigger trg_transactions_updated before update on transactions
  for each row execute function touch_updated_at();

-- ─────────────────────────────────────────────
-- Seed data (matches the prototype)
-- ─────────────────────────────────────────────
insert into doctors (id, full_name, specialty, schedule) values
  ('DR-001', 'Dr. Ramon Villanueva', 'Internal Medicine', 'Mon-Fri, 8AM-4PM'),
  ('DR-002', 'Dr. Feliza Ong', 'OB-GYN', 'Tue-Sat, 9AM-5PM'),
  ('DR-003', 'Dr. Miguel Bautista', 'Cardiology', 'Mon, Wed, Fri, 1PM-6PM');

insert into patients (id, full_name, age, gender, phone, condition, registered_at) values
  ('PT-0001', 'Maria Santos', 34, 'Female', '0917 234 5566', 'Hypertension follow-up', '2026-08-12'),
  ('PT-0002', 'Carlos Reyes', 58, 'Male', '0928 112 3344', 'Diabetes management', '2026-08-14'),
  ('PT-0003', 'Angela Cruz', 27, 'Female', '0905 887 6621', 'Prenatal checkup', '2026-08-18');

insert into transactions (id, patient_id, doctor_id, type, amount, status, visit_date) values
  ('TX-1001', 'PT-0001', 'DR-001', 'Consultation', 800, 'Completed', '2026-08-25'),
  ('TX-1002', 'PT-0002', 'DR-001', 'Follow-up', 500, 'Completed', '2026-08-26'),
  ('TX-1003', 'PT-0003', 'DR-002', 'Prenatal Checkup', 1200, 'Pending', '2026-08-27');
