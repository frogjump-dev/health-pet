-- Day strain and sleep performance feed the Whoop-only pets (Protein Bar, Warm Milk, Honey).
alter table public.daily_snapshots
  add column strain            double precision,
  add column sleep_performance double precision;
