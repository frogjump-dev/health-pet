# HealthPet backend (Supabase)

Holds each user's Whoop link and serves their daily Whoop numbers to the app.
Apple Health data never comes here; it stays on the phone.

```
App ──(anonymous Supabase session)──► whoop-connect ──► Whoop login in a browser sheet
                                                         │
Whoop ──► whoop-callback (exchange code, store encrypted tokens, backfill 30 days)
      │                    └──► redirect healthpet://whoop/connected?status=ok
      └─► whoop-webhook (sleep/recovery updated → re-sync last 3 days)

App ──► snapshots?from&to (re-syncs if older than 30 min) ──► daily_snapshots
```

| Function | Who calls it | What it does |
|---|---|---|
| `whoop-connect` | app (signed in) | returns the Whoop authorize URL with a one-time state |
| `whoop-callback` | browser, redirected by Whoop | stores tokens, backfills, sends the browser back to the app |
| `whoop-webhook` | Whoop | verifies the HMAC signature, dedupes by `trace_id`, re-syncs in the background |
| `snapshots` | app (signed in) | `{ connected, snapshots: [...] }` for a date range |
| `whoop-disconnect` | app (signed in) | deletes tokens and stored Whoop data |

Shared code lives in `supabase/functions/_shared/`: `whoop.ts` (pure logic, unit tested),
`whoopClient.ts` (Whoop HTTP), `crypto.ts` (AES-GCM for tokens), `service.ts` (database + config).

## Tests

```
cd backend
npm install
npm test          # unit tests for signatures, mapping, encryption, pagination
npm run typecheck
```

## Going live (one-time setup)

1. **Supabase**: create a project. In Authentication → Sign In / Providers → User Signups, turn on *Allow anonymous sign-ins*.
2. **Whoop**: create an app at developer-dashboard.whoop.com.
   - Redirect URL: `https://<project-ref>.supabase.co/functions/v1/whoop-callback`
   - Webhook URL (model v2): `https://<project-ref>.supabase.co/functions/v1/whoop-webhook`
   - Scopes: offline, read:recovery, read:sleep, read:cycles, read:profile
3. **Deploy** with the Supabase CLI:
   ```
   supabase link --project-ref <project-ref>
   supabase db push
   supabase secrets set --env-file supabase/.env.whoop
   supabase functions deploy
   ```
   `supabase/.env.whoop` is gitignored and never leaves your machine. It holds:
   ```
   WHOOP_CLIENT_ID=…
   WHOOP_CLIENT_SECRET=…
   WHOOP_REDIRECT_URI=https://<project-ref>.supabase.co/functions/v1/whoop-callback
   TOKEN_ENCRYPTION_KEY=<output of: openssl rand -base64 32>
   ```
4. **App**: copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig`, fill in the
   project ref and anon key, then `xcodegen generate`.
