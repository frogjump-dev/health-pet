import { test } from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import {
  buildAuthorizeUrl,
  localDay,
  newOAuthState,
  toDTO,
  toSnapshotRows,
  verifyWebhookSignature,
  type WhoopRecovery,
  type WhoopSleep,
} from "../supabase/functions/_shared/whoop.ts";
import { decryptToken, encryptToken } from "../supabase/functions/_shared/crypto.ts";
import { listSleeps, refreshTokens } from "../supabase/functions/_shared/whoopClient.ts";

const SECRET = "whoop-client-secret";

function sign(timestamp: string, body: string): string {
  return createHmac("sha256", SECRET).update(timestamp + body).digest("base64");
}

test("authorize URL carries offline scope, code flow and state", () => {
  const url = new URL(buildAuthorizeUrl({ clientId: "abc", redirectUri: "https://x.supabase.co/functions/v1/whoop-callback", state: "Abcd2345" }));
  assert.equal(url.searchParams.get("response_type"), "code");
  assert.equal(url.searchParams.get("state"), "Abcd2345");
  assert.ok(url.searchParams.get("scope")!.split(" ").includes("offline"));
});

test("OAuth state is exactly 8 characters", () => {
  for (let i = 0; i < 50; i++) assert.match(newOAuthState(), /^[A-Za-z0-9]{8}$/);
});

test("webhook signature: valid, tampered, stale, missing", async () => {
  const body = JSON.stringify({ user_id: 1, id: "u", type: "recovery.updated", trace_id: "t" });
  const now = 1_790_000_000_000;
  const ts = String(now - 1000);
  const ok = await verifyWebhookSignature({ rawBody: body, signature: sign(ts, body), timestamp: ts, clientSecret: SECRET, now });
  assert.equal(ok, true);

  const tampered = await verifyWebhookSignature({ rawBody: body + " ", signature: sign(ts, body), timestamp: ts, clientSecret: SECRET, now });
  assert.equal(tampered, false);

  const old = String(now - 10 * 60_000);
  const stale = await verifyWebhookSignature({ rawBody: body, signature: sign(old, body), timestamp: old, clientSecret: SECRET, now });
  assert.equal(stale, false);

  assert.equal(await verifyWebhookSignature({ rawBody: body, signature: null, timestamp: ts, clientSecret: SECRET, now }), false);
});

test("local day follows the time zone the sleep was recorded in", () => {
  // 06:30 UTC is still the previous evening in Los Angeles, already afternoon in Shanghai.
  assert.equal(localDay("2026-10-28T06:30:00.000Z", "-07:00"), "2026-10-27");
  assert.equal(localDay("2026-10-27T23:30:00.000Z", "+08:00"), "2026-10-28");
  assert.equal(localDay("2026-10-28T06:30:00.000Z", "Z"), "2026-10-28");
});

const stages = (hours: number) => ({
  stage_summary: {
    total_light_sleep_time_milli: hours * 0.5 * 3_600_000,
    total_slow_wave_sleep_time_milli: hours * 0.25 * 3_600_000,
    total_rem_sleep_time_milli: hours * 0.25 * 3_600_000,
  },
});

function sleep(id: string, end: string, hours: number, extra: Partial<WhoopSleep> = {}): WhoopSleep {
  const start = new Date(Date.parse(end) - hours * 3_600_000).toISOString();
  return { id, cycle_id: 1, start, end, timezone_offset: "+00:00", nap: false, score_state: "SCORED", score: stages(hours), ...extra };
}

function recovery(sleepId: string, score: number, extra: Partial<WhoopRecovery["score"]> = {}): WhoopRecovery {
  return {
    cycle_id: 1,
    sleep_id: sleepId,
    score_state: "SCORED",
    score: { user_calibrating: false, recovery_score: score, resting_heart_rate: 52, hrv_rmssd_milli: 61.234, ...extra },
  };
}

test("sleep + recovery become one snapshot per day", () => {
  const rows = toSnapshotRows([sleep("s1", "2026-10-27T07:00:00Z", 7.5), sleep("s2", "2026-10-28T07:00:00Z", 6)], [recovery("s1", 80), recovery("s2", 40)]);
  assert.equal(rows.length, 2);
  assert.deepEqual(rows[1], {
    source: "whoop",
    day: "2026-10-28",
    sleep_hours: 6,
    hrv_ms: 61.2,
    hrv_method: "rmssd",
    resting_heart_rate: 52,
    vendor_recovery: 40,
    strain: null,
    sleep_performance: null,
    sleep_onset: "2026-10-28T01:00:00.000Z",
    wake_time: "2026-10-28T07:00:00Z",
    whoop_sleep_id: "s2",
  });
});

test("asleep and awake times are Whoop's own sleep start and end, sent to the app", () => {
  // Asleep 22:48 and awake 06:40 in Los Angeles.
  const s = sleep("s", "2026-10-28T13:40:00.000Z", 7, { start: "2026-10-28T05:48:12.345Z", timezone_offset: "-07:00" });
  const [row] = toSnapshotRows([s], []);
  assert.equal(row.day, "2026-10-28"); // the morning the user woke up, where they slept
  assert.equal(row.sleep_onset, "2026-10-28T05:48:12.345Z");
  assert.equal(row.wake_time, "2026-10-28T13:40:00.000Z");
  const dto = toDTO(row);
  assert.equal(dto.sleepOnset, "2026-10-28T05:48:12.345Z");
  assert.equal(dto.wakeTime, "2026-10-28T13:40:00.000Z");
  // Rows saved before the columns existed come back without them.
  const { sleep_onset: _a, wake_time: _b, ...old } = row;
  assert.equal(toDTO(old as typeof row).sleepOnset, null);
});

test("naps are ignored and the longest main sleep wins", () => {
  const rows = toSnapshotRows(
    [
      sleep("nap", "2026-10-28T14:00:00Z", 1, { nap: true }),
      sleep("short", "2026-10-28T03:00:00Z", 2),
      sleep("main", "2026-10-28T07:00:00Z", 7),
    ],
    [recovery("main", 70)],
  );
  assert.equal(rows.length, 1);
  assert.equal(rows[0].whoop_sleep_id, "main");
  assert.equal(rows[0].vendor_recovery, 70);
});

test("unscored data and calibrating recovery are left empty", () => {
  const rows = toSnapshotRows(
    [sleep("a", "2026-10-27T07:00:00Z", 7, { score_state: "PENDING_SCORE", score: undefined }), sleep("b", "2026-10-28T07:00:00Z", 7)],
    [recovery("b", 90, { user_calibrating: true })],
  );
  assert.equal(rows[0].sleep_hours, null);
  assert.equal(rows[1].vendor_recovery, null);
  assert.equal(rows[1].hrv_ms, 61.2); // HRV is still a real measurement while calibrating
});

test("DTO uses the app's field names", () => {
  const [row] = toSnapshotRows([sleep("s", "2026-10-28T07:00:00Z", 8)], [recovery("s", 66)]);
  assert.deepEqual(Object.keys(toDTO(row)).sort(),
    ["day", "hrvMethod", "hrvMs", "restingHeartRate", "sleepHours", "sleepOnset", "sleepPerformance", "source", "strain",
      "vendorRecovery", "wakeTime"]);
});

test("day strain comes from the cycle the sleep starts; sleep performance from the sleep", () => {
  const s = sleep("s", "2026-10-28T07:00:00Z", 8, { cycle_id: 42 });
  s.score = { ...stages(8), sleep_performance_percentage: 91 };
  const [row] = toSnapshotRows([s], [recovery("s", 70)], [
    { id: 41, score_state: "SCORED", score: { strain: 9.9 } },
    { id: 42, score_state: "SCORED", score: { strain: 14.26 } },
  ]);
  assert.equal(row.strain, 14.3);
  assert.equal(row.sleep_performance, 91);
  const [noCycle] = toSnapshotRows([sleep("t", "2026-10-29T07:00:00Z", 7)], []);
  assert.equal(noCycle.strain, null);
  assert.equal(noCycle.sleep_performance, null);
});

test("tokens round-trip through AES-GCM and fail with the wrong key", async () => {
  const key = Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString("base64");
  const other = Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString("base64");
  const sealed = await encryptToken("secret-token", key);
  assert.notEqual(sealed, await encryptToken("secret-token", key)); // fresh IV each time
  assert.equal(await decryptToken(sealed, key), "secret-token");
  await assert.rejects(decryptToken(sealed, other));
});

test("refresh sends offline scope as a form", async () => {
  let captured: { url: string; body: string } | undefined;
  const fakeFetch = (async (url: string | URL, init?: RequestInit) => {
    captured = { url: String(url), body: String(init?.body) };
    return new Response(JSON.stringify({ access_token: "a", refresh_token: "r", expires_in: 3600 }), { status: 200 });
  }) as typeof fetch;
  const tokens = await refreshTokens(fakeFetch, { refreshToken: "old", clientId: "id", clientSecret: "sec" });
  assert.equal(tokens.refresh_token, "r");
  const form = new URLSearchParams(captured!.body);
  assert.equal(form.get("grant_type"), "refresh_token");
  assert.equal(form.get("scope"), "offline");
});

test("listSleeps follows next_token pagination", async () => {
  const pages = [
    { records: [{ id: "1" }], next_token: "p2" },
    { records: [{ id: "2" }], next_token: null },
  ];
  const seen: string[] = [];
  const fakeFetch = (async (url: string | URL) => {
    const u = new URL(String(url));
    seen.push(u.searchParams.get("nextToken") ?? "-");
    assert.equal(u.pathname, "/developer/v2/activity/sleep");
    return new Response(JSON.stringify(pages.shift()), { status: 200 });
  }) as typeof fetch;
  const records = await listSleeps(fakeFetch, "tok", new Date(0), new Date(1));
  assert.deepEqual(records.map((r) => r.id), ["1", "2"]);
  assert.deepEqual(seen, ["-", "p2"]);
});
