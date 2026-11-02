// Database-backed pieces shared by the edge functions: config, auth, token storage
// with single-flight refresh, and syncing Whoop data into daily_snapshots.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { decryptToken, encryptToken } from "./crypto.ts";
import { toSnapshotRows } from "./whoop.ts";
import { listCycles, listRecoveries, listSleeps, refreshTokens, type WhoopTokens } from "./whoopClient.ts";

export interface Config {
  supabaseUrl: string;
  serviceRoleKey: string;
  whoopClientId: string;
  whoopClientSecret: string;
  whoopRedirectUri: string;
  tokenKey: string;
  /** Where the browser goes after OAuth, e.g. healthpet://whoop/connected */
  appReturnUrl: string;
}

export function loadConfig(): Config {
  const get = (name: string) => {
    const value = Deno.env.get(name);
    if (!value) throw new Error(`Missing secret ${name}`);
    return value;
  };
  return {
    supabaseUrl: get("SUPABASE_URL"),
    serviceRoleKey: get("SUPABASE_SERVICE_ROLE_KEY"),
    whoopClientId: get("WHOOP_CLIENT_ID"),
    whoopClientSecret: get("WHOOP_CLIENT_SECRET"),
    whoopRedirectUri: get("WHOOP_REDIRECT_URI"),
    tokenKey: get("TOKEN_ENCRYPTION_KEY"),
    appReturnUrl: Deno.env.get("APP_RETURN_URL") ?? "healthpet://whoop/connected",
  };
}

export function adminClient(config: Config): SupabaseClient {
  return createClient(config.supabaseUrl, config.serviceRoleKey, { auth: { persistSession: false } });
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

/** The signed-in app user, from the Supabase JWT the app sends as a bearer token. */
export async function requireUser(db: SupabaseClient, req: Request): Promise<string | null> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data, error } = await db.auth.getUser(token);
  return error || !data.user ? null : data.user.id;
}

export async function saveTokens(
  db: SupabaseClient,
  config: Config,
  userId: string,
  whoopUserId: number | null,
  tokens: WhoopTokens,
): Promise<void> {
  const row: Record<string, unknown> = {
    user_id: userId,
    access_token: await encryptToken(tokens.access_token, config.tokenKey),
    refresh_token: await encryptToken(tokens.refresh_token, config.tokenKey),
    expires_at: new Date(Date.now() + tokens.expires_in * 1000).toISOString(),
    scope: tokens.scope ?? null,
    refreshing_until: null,
    updated_at: new Date().toISOString(),
  };
  // A first connection inserts the row; a token refresh only updates it (an upsert without
  // the NOT NULL whoop_user_id would be rejected before the conflict is detected).
  const { error } = whoopUserId !== null
    ? await db.from("whoop_connections").upsert({ ...row, whoop_user_id: whoopUserId })
    : await db.from("whoop_connections").update(row).eq("user_id", userId);
  if (error) throw error;
}

/**
 * Returns a usable access token, refreshing it when it expires within 5 minutes.
 * Whoop invalidates the old refresh token on use, so concurrent callers must not both
 * refresh: one claims the lock, the others wait for its result.
 */
export async function accessTokenFor(db: SupabaseClient, config: Config, userId: string): Promise<string | null> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const { data: conn } = await db
      .from("whoop_connections")
      .select("access_token, refresh_token, expires_at")
      .eq("user_id", userId)
      .maybeSingle();
    if (!conn) return null;

    if (Date.parse(conn.expires_at) - Date.now() > 5 * 60_000) {
      return decryptToken(conn.access_token, config.tokenKey);
    }

    const { data: claimed } = await db.rpc("claim_whoop_refresh", { p_user_id: userId });
    if (claimed) {
      const tokens = await refreshTokens(fetch, {
        refreshToken: await decryptToken(conn.refresh_token, config.tokenKey),
        clientId: config.whoopClientId,
        clientSecret: config.whoopClientSecret,
      });
      await saveTokens(db, config, userId, null, tokens);
      return tokens.access_token;
    }
    await new Promise((r) => setTimeout(r, 1500));
  }
  throw new Error("Timed out waiting for another Whoop token refresh");
}

/** Pulls `days` days of Whoop sleep, recovery and cycle strain and upserts them as daily snapshots. */
export async function syncUser(db: SupabaseClient, config: Config, userId: string, days: number): Promise<number> {
  const accessToken = await accessTokenFor(db, config, userId);
  if (!accessToken) return 0;

  const end = new Date();
  // One extra day so a night that started before the window still counts.
  const start = new Date(end.getTime() - (days + 1) * 86_400_000);
  const [sleeps, recoveries, cycles] = await Promise.all([
    listSleeps(fetch, accessToken, start, end),
    listRecoveries(fetch, accessToken, start, end),
    listCycles(fetch, accessToken, start, end),
  ]);

  const rows = toSnapshotRows(sleeps, recoveries, cycles).map((r) => ({
    ...r,
    user_id: userId,
    updated_at: new Date().toISOString(),
  }));
  if (rows.length > 0) {
    const { error } = await db.from("daily_snapshots").upsert(rows);
    if (error) throw error;
  }
  await db.from("whoop_connections").update({ last_synced_at: new Date().toISOString() }).eq("user_id", userId);
  return rows.length;
}
