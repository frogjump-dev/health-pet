// GET /whoop-callback?code=…&state=…  (Whoop redirects the browser here)
// Exchanges the code, stores encrypted tokens, backfills 30 days, then sends the browser
// back to the app: healthpet://whoop/connected?status=ok|error

import { getProfile, exchangeCode } from "../_shared/whoopClient.ts";
import { adminClient, loadConfig, saveTokens, syncUser } from "../_shared/service.ts";

const STATE_MAX_AGE_MS = 10 * 60_000;
const BACKFILL_DAYS = 30;

Deno.serve(async (req) => {
  const config = loadConfig();
  const db = adminClient(config);
  const params = new URL(req.url).searchParams;

  const back = (status: "ok" | "error", reason?: string) => {
    const url = new URL(config.appReturnUrl);
    url.searchParams.set("status", status);
    if (reason) url.searchParams.set("reason", reason);
    return Response.redirect(url.toString(), 302);
  };

  const code = params.get("code");
  const state = params.get("state");
  if (params.get("error")) return back("error", "denied");
  if (!code || !state) return back("error", "missing_code");

  // States are single use: delete and read in one step.
  const { data: stateRow } = await db.from("oauth_states").delete().eq("state", state).select().maybeSingle();
  if (!stateRow || Date.now() - Date.parse(stateRow.created_at) > STATE_MAX_AGE_MS) {
    return back("error", "bad_state");
  }

  try {
    const tokens = await exchangeCode(fetch, {
      code,
      clientId: config.whoopClientId,
      clientSecret: config.whoopClientSecret,
      redirectUri: config.whoopRedirectUri,
    });
    const profile = await getProfile(fetch, tokens.access_token);

    // One Whoop account belongs to one app user; reconnecting from a new install moves it.
    await db.from("whoop_connections").delete().eq("whoop_user_id", profile.user_id).neq("user_id", stateRow.user_id);
    await saveTokens(db, config, stateRow.user_id, profile.user_id, tokens);

    await syncUser(db, config, stateRow.user_id, BACKFILL_DAYS);
    return back("ok");
  } catch (err) {
    console.error("whoop-callback failed", err);
    return back("error", "exchange_failed");
  }
});
