// POST /whoop-disconnect  (signed-in app user)
// Forgets the user's Whoop tokens and the Whoop data we stored for them.

import { adminClient, json, loadConfig, requireUser } from "../_shared/service.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const config = loadConfig();
  const db = adminClient(config);
  const userId = await requireUser(db, req);
  if (!userId) return json({ error: "unauthorized" }, 401);

  await db.from("whoop_connections").delete().eq("user_id", userId);
  await db.from("daily_snapshots").delete().eq("user_id", userId).eq("source", "whoop");
  return json({ connected: false });
});
