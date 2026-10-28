// POST /whoop-connect  (signed-in app user)
// Creates a one-time OAuth state and returns the Whoop authorize URL for the app to open
// in ASWebAuthenticationSession.

import { buildAuthorizeUrl, newOAuthState } from "../_shared/whoop.ts";
import { adminClient, json, loadConfig, requireUser } from "../_shared/service.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const config = loadConfig();
  const db = adminClient(config);
  const userId = await requireUser(db, req);
  if (!userId) return json({ error: "unauthorized" }, 401);

  // Drop this user's stale states so the table doesn't grow.
  await db.from("oauth_states").delete().eq("user_id", userId);

  const state = newOAuthState();
  const { error } = await db.from("oauth_states").insert({ state, user_id: userId });
  if (error) return json({ error: "state_failed" }, 500);

  const url = buildAuthorizeUrl({ clientId: config.whoopClientId, redirectUri: config.whoopRedirectUri, state });
  return json({ url });
});
