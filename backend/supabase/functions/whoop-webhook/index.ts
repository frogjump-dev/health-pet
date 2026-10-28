// POST /whoop-webhook  (called by Whoop, v2 model)
// Verifies the signature, answers 200 right away, and re-syncs the last few days for that
// user in the background. Re-syncing a small window is simpler than fetching single records
// and also heals any webhook we missed.

import { verifyWebhookSignature, type WhoopWebhookEvent } from "../_shared/whoop.ts";
import { adminClient, loadConfig, syncUser } from "../_shared/service.ts";

const RESYNC_DAYS = 3;

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void };

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const config = loadConfig();
  const rawBody = await req.text();
  const valid = await verifyWebhookSignature({
    rawBody,
    signature: req.headers.get("X-WHOOP-Signature"),
    timestamp: req.headers.get("X-WHOOP-Signature-Timestamp"),
    clientSecret: config.whoopClientSecret,
  });
  if (!valid) return new Response("bad signature", { status: 401 });

  const event = JSON.parse(rawBody) as WhoopWebhookEvent;
  if (!event.type.startsWith("sleep.") && !event.type.startsWith("recovery.")) {
    return new Response("ignored", { status: 200 });
  }

  const db = adminClient(config);

  // Whoop retries; the primary key on trace_id drops duplicates.
  const { error: dupe } = await db.from("whoop_webhook_events").insert({ trace_id: event.trace_id });
  if (dupe) return new Response("duplicate", { status: 200 });

  const { data: conn } = await db
    .from("whoop_connections")
    .select("user_id")
    .eq("whoop_user_id", event.user_id)
    .maybeSingle();
  if (!conn) return new Response("unknown user", { status: 200 });

  EdgeRuntime.waitUntil(
    syncUser(db, config, conn.user_id, RESYNC_DAYS).catch((err) => console.error("webhook sync failed", err)),
  );
  return new Response("ok", { status: 200 });
});
