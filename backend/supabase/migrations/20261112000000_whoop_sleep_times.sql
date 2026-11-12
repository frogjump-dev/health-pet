-- When Whoop's main sleep started and ended. The app uses them as the asleep and awake times
-- for Whoop users instead of working anything out itself (PRD v0.3 「只读原值」, 2026-11-10).
alter table public.daily_snapshots
  add column sleep_onset timestamptz,
  add column wake_time   timestamptz;
