// Pure Whoop logic: OAuth URLs, webhook signatures and mapping Whoop records to daily
// snapshots. No network or database access here, so it runs under Deno (edge functions)
// and Node (unit tests) alike.

export const WHOOP_AUTH_URL = "https://api.prod.whoop.com/oauth/oauth2/auth";
export const WHOOP_TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token";
export const WHOOP_API_BASE = "https://api.prod.whoop.com/developer";

// `offline` is what makes Whoop return a refresh token.
export const WHOOP_SCOPES = ["offline", "read:recovery", "read:sleep", "read:cycles", "read:profile"];

export function buildAuthorizeUrl(params: { clientId: string; redirectUri: string; state: string }): string {
  const url = new URL(WHOOP_AUTH_URL);
  url.searchParams.set("client_id", params.clientId);
  url.searchParams.set("redirect_uri", params.redirectUri);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("scope", WHOOP_SCOPES.join(" "));
  url.searchParams.set("state", params.state);
  return url.toString();
}

/** Whoop requires an 8-character state when the client generates it. */
export function newOAuthState(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
}

// MARK: - Webhooks

export interface WhoopWebhookEvent {
  user_id: number;
  /** v2: UUID. For recovery events this is the UUID of the associated sleep. */
  id: string;
  type: string;
  trace_id: string;
}

/** Webhook signatures older than this are rejected to limit replays. */
export const WEBHOOK_MAX_AGE_MS = 5 * 60 * 1000;

/**
 * Whoop signs `timestamp + rawBody` with HMAC-SHA256 keyed by the client secret,
 * base64-encoded, in `X-WHOOP-Signature`; the timestamp (ms) is in `X-WHOOP-Signature-Timestamp`.
 */
export async function verifyWebhookSignature(params: {
  rawBody: string;
  signature: string | null;
  timestamp: string | null;
  clientSecret: string;
  now?: number;
}): Promise<boolean> {
  const { rawBody, signature, timestamp, clientSecret } = params;
  if (!signature || !timestamp) return false;

  const sentAt = Number(timestamp);
  const now = params.now ?? Date.now();
  if (!Number.isFinite(sentAt) || Math.abs(now - sentAt) > WEBHOOK_MAX_AGE_MS) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(clientSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(timestamp + rawBody));
  return timingSafeEqual(bytesToBase64(new Uint8Array(mac)), signature);
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary);
}

export function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

// MARK: - Records → daily snapshots

export type ScoreState = "SCORED" | "PENDING_SCORE" | "UNSCORABLE";

export interface WhoopSleep {
  id: string;
  cycle_id: number;
  start: string;
  end: string;
  /** e.g. "-05:00" */
  timezone_offset: string;
  nap: boolean;
  score_state: ScoreState;
  score?: {
    /** Sleep got vs. the sleep Whoop says the user needed, 0-100. */
    sleep_performance_percentage?: number;
    stage_summary: {
      total_light_sleep_time_milli: number;
      total_slow_wave_sleep_time_milli: number;
      total_rem_sleep_time_milli: number;
    };
  };
}

export interface WhoopRecovery {
  cycle_id: number;
  sleep_id: string;
  score_state: ScoreState;
  score?: {
    user_calibrating: boolean;
    recovery_score: number;
    resting_heart_rate: number;
    hrv_rmssd_milli: number;
  };
}

/** A physiological cycle: from falling asleep to falling asleep again. Its strain is that day's strain. */
export interface WhoopCycle {
  id: number;
  score_state: ScoreState;
  score?: {
    strain: number;
  };
}

/** A row of `daily_snapshots`, minus user_id. */
export interface SnapshotRow {
  source: "whoop";
  day: string; // YYYY-MM-DD, local to where the user slept
  sleep_hours: number | null;
  hrv_ms: number | null;
  hrv_method: "rmssd" | null;
  resting_heart_rate: number | null;
  vendor_recovery: number | null;
  /** Day strain 0-21 of the cycle that began with this sleep (still rising while the day is going). */
  strain: number | null;
  sleep_performance: number | null;
  whoop_sleep_id: string;
}

/** The calendar day a sleep ended on, in the time zone it was recorded in. */
export function localDay(isoInstant: string, timezoneOffset: string): string {
  const match = /^([+-])(\d{2}):?(\d{2})$/.exec(timezoneOffset);
  const offsetMinutes = match ? (match[1] === "-" ? -1 : 1) * (Number(match[2]) * 60 + Number(match[3])) : 0;
  const local = new Date(Date.parse(isoInstant) + offsetMinutes * 60_000);
  return local.toISOString().slice(0, 10);
}

/**
 * Builds one snapshot per day from main sleeps (naps ignored), their recoveries and the
 * strain of the cycle each sleep starts. If several main sleeps end on the same day, the longest wins.
 */
export function toSnapshotRows(sleeps: WhoopSleep[], recoveries: WhoopRecovery[], cycles: WhoopCycle[] = []): SnapshotRow[] {
  const recoveryBySleep = new Map(recoveries.map((r) => [r.sleep_id, r]));
  const cycleById = new Map(cycles.map((c) => [c.id, c]));
  const byDay = new Map<string, SnapshotRow>();

  for (const sleep of sleeps) {
    if (sleep.nap) continue;

    const day = localDay(sleep.end, sleep.timezone_offset);
    const stages = sleep.score_state === "SCORED" ? sleep.score?.stage_summary : undefined;
    const sleepHours = stages
      ? (stages.total_light_sleep_time_milli + stages.total_slow_wave_sleep_time_milli + stages.total_rem_sleep_time_milli) /
        3_600_000
      : null;

    const recovery = recoveryBySleep.get(sleep.id);
    const score = recovery?.score_state === "SCORED" ? recovery.score : undefined;
    const cycle = cycleById.get(sleep.cycle_id);
    const performance = sleep.score_state === "SCORED" ? sleep.score?.sleep_performance_percentage : undefined;

    const row: SnapshotRow = {
      source: "whoop",
      day,
      sleep_hours: sleepHours === null ? null : round(sleepHours, 2),
      hrv_ms: score ? round(score.hrv_rmssd_milli, 1) : null,
      hrv_method: score ? "rmssd" : null,
      resting_heart_rate: score?.resting_heart_rate ?? null,
      // While Whoop is still calibrating a new user, its recovery score isn't meaningful yet.
      vendor_recovery: score && !score.user_calibrating ? score.recovery_score : null,
      // A cycle in progress is still scored as it goes, so today's strain rises during the day.
      strain: cycle?.score ? round(cycle.score.strain, 1) : null,
      sleep_performance: performance ?? null,
      whoop_sleep_id: sleep.id,
    };

    const existing = byDay.get(day);
    if (!existing || (row.sleep_hours ?? 0) > (existing.sleep_hours ?? 0)) byDay.set(day, row);
  }

  return [...byDay.values()].sort((a, b) => a.day.localeCompare(b.day));
}

function round(value: number, digits: number): number {
  const f = 10 ** digits;
  return Math.round(value * f) / f;
}

// MARK: - API response for the app

/** JSON the app decodes (see WhoopProvider.swift). Field names match PetCore.HealthSnapshot. */
export interface SnapshotDTO {
  day: string;
  source: "whoop";
  sleepHours: number | null;
  hrvMs: number | null;
  hrvMethod: "rmssd" | null;
  restingHeartRate: number | null;
  vendorRecovery: number | null;
  strain: number | null;
  sleepPerformance: number | null;
}

export function toDTO(row: SnapshotRow): SnapshotDTO {
  return {
    day: row.day,
    source: row.source,
    sleepHours: row.sleep_hours,
    hrvMs: row.hrv_ms,
    hrvMethod: row.hrv_method,
    restingHeartRate: row.resting_heart_rate,
    vendorRecovery: row.vendor_recovery,
    strain: row.strain,
    sleepPerformance: row.sleep_performance,
  };
}
