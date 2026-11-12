-- When Whoop's main sleep started and ended. The app uses them as the asleep and awake times
-- for Whoop users instead of working anything out itself (PRD v0.3 「只读原值」, 2026-11-10).
-- "if not exists": the columns were first added by hand (2026-11-12), so this can run again.
alter table public.daily_snapshots
  add column if not exists sleep_onset timestamptz,
  add column if not exists wake_time   timestamptz;
