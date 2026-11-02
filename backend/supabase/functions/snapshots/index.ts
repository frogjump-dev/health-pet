// GET /snapshots?from=YYYY-MM-DD&to=YYYY-MM-DD  (signed-in app user)
// Returns { connected, snapshots: SnapshotDTO[] }. If the last Whoop sync is older than
// 30 minutes it syncs first, which also covers webhooks that never arrived.

import { toDTO, type SnapshotRow } from "../_shared/whoop.ts";
import { adminClient, json, loadConfig, requireUser, syncUser } from "../_shared/service.ts";

const STALE_AFTER_MS = 30 * 60_000;
const DAY = /^\d{4}-\d{2}-\d{2}$/;

Deno.serve(async (req) => {
  if (req.method !== "GET") return json({ error: "method_not_allowed" }, 405);

  const config = loadConfig();
  const db = adminClient(config);
  const userId = await requireUser(db, req);
  if (!userId) return json({ error: "unauthorized" }, 401);

  const params = new URL(req.url).searchParams;
  const from = params.get("from") ?? "";
  const to = params.get("to") ?? "";
  if (!DAY.test(from) || !DAY.test(to)) return json({ error: "from_and_to_required" }, 400);

  const { data: conn } = await db
    .from("whoop_connections")
    .select("last_synced_at")
    .eq("user_id", userId)
    .maybeSingle();
  if (!conn) return json({ connected: false, snapshots: [] });

  if (!conn.last_synced_at || Date.now() - Date.parse(conn.last_synced_at) > STALE_AFTER_MS) {
    try {
      await syncUser(db, config, userId, 3);
    } catch (err) {
      // Serve what we have; the app shows yesterday's pet rather than an error.
      console.error("on-demand sync failed", err);
    }
  }

  const { data, error } = await db
    .from("daily_snapshots")
    .select("source, day, sleep_hours, hrv_ms, hrv_method, resting_heart_rate, vendor_recovery, strain, sleep_performance, whoop_sleep_id")
    .eq("user_id", userId)
    .gte("day", from)
    .lte("day", to)
    .order("day");
  if (error) return json({ error: "query_failed" }, 500);

  return json({ connected: true, snapshots: (data as SnapshotRow[]).map(toDTO) });
});
