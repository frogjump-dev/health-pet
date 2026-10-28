-- Whoop integration: OAuth connections, daily snapshots served to the app, webhook dedupe.
-- Tables without RLS policies are only reachable with the service role (edge functions).

create table public.whoop_connections (
  user_id           uuid primary key references auth.users on delete cascade,
  whoop_user_id     bigint not null unique,
  -- Tokens are AES-GCM encrypted by the edge functions (TOKEN_ENCRYPTION_KEY) before they land here.
  access_token      text not null,
  refresh_token     text not null,
  expires_at        timestamptz not null,
  scope             text,
  -- Whoop invalidates the old refresh token on use, so only one refresh may run at a time.
  refreshing_until  timestamptz,
  last_synced_at    timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
alter table public.whoop_connections enable row level security;

-- Short-lived OAuth state values (CSRF protection), one per "Connect Whoop" tap.
create table public.oauth_states (
  state       text primary key,
  user_id     uuid not null references auth.users on delete cascade,
  created_at  timestamptz not null default now()
);
alter table public.oauth_states enable row level security;

-- One row per user, source and calendar day (the day the night's sleep ended, in the
-- user's local time). Mirrors PetCore.HealthSnapshot.
create table public.daily_snapshots (
  user_id             uuid not null references auth.users on delete cascade,
  source              text not null check (source in ('whoop')),
  day                 date not null,
  sleep_hours         double precision,
  hrv_ms              double precision,
  hrv_method          text check (hrv_method in ('sdnn', 'rmssd')),
  resting_heart_rate  double precision,
  vendor_recovery     double precision,
  whoop_sleep_id      uuid,
  updated_at          timestamptz not null default now(),
  primary key (user_id, source, day)
);
alter table public.daily_snapshots enable row level security;
create policy "Users read their own snapshots"
  on public.daily_snapshots for select
  using (auth.uid() = user_id);

-- Whoop retries deliveries; trace_id lets us drop duplicates.
create table public.whoop_webhook_events (
  trace_id     text primary key,
  received_at  timestamptz not null default now()
);
alter table public.whoop_webhook_events enable row level security;

-- Atomically claims the right to refresh a user's Whoop token for 30 seconds.
-- Returns true for exactly one caller; others should wait and re-read the row.
create function public.claim_whoop_refresh(p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  update public.whoop_connections
     set refreshing_until = now() + interval '30 seconds'
   where user_id = p_user_id
     and (refreshing_until is null or refreshing_until < now())
  returning true;
$$;
revoke all on function public.claim_whoop_refresh(uuid) from public, anon, authenticated;
