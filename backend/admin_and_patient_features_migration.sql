-- MedTrack — migration for the Patient/Doctor/Admin module update
-- Run this in Supabase > SQL Editor > New query, in addition to the
-- earlier fixes you've already applied.

-- New storage slots the app now needs:
--   patients.photo_path — local file path to the patient's profile photo
--   patients.is_active / doctors.is_active — set by the Admin to turn an
--     account on/off (1 = active, 0 = inactive). Stored as integer to
--     exactly match what the app sends (0/1), avoiding type-mismatch errors.
--   patients.status / doctors.status — the same active/inactive state,
--     but as plain readable text ("active" / "inactive"), so it's easy to
--     see at a glance when looking directly at the table in Supabase.
alter table patients add column if not exists photo_path text;
alter table patients add column if not exists is_active integer not null default 1;
alter table patients add column if not exists status text not null default 'active';
alter table doctors add column if not exists is_active integer not null default 1;
alter table doctors add column if not exists status text not null default 'active';

-- Keep status text matching is_active for any rows that already existed
-- before this column was added.
update patients set status = case when is_active = 1 then 'active' else 'inactive' end;
update doctors set status = case when is_active = 1 then 'active' else 'inactive' end;

-- Appointments can now be Accepted or Declined by the doctor, in addition
-- to Pending/Completed — widen the allowed values.
alter table transactions drop constraint if exists transactions_status_check;
alter table transactions add constraint transactions_status_check
  check (status in ('Pending', 'Accepted', 'Completed', 'Declined', 'Cancelled'));
