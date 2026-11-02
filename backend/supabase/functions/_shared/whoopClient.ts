// Network side of Whoop: token exchange/refresh and paginated reads.
// Takes `fetch` as a parameter so tests can stub it.

import { WHOOP_API_BASE, WHOOP_TOKEN_URL, type WhoopCycle, type WhoopRecovery, type WhoopSleep } from "./whoop.ts";

export interface WhoopTokens {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  scope?: string;
}

type Fetch = typeof fetch;

export class WhoopError extends Error {
  readonly status: number;

  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

async function postForm(fetchFn: Fetch, body: Record<string, string>): Promise<WhoopTokens> {
  const res = await fetchFn(WHOOP_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(body).toString(),
  });
  if (!res.ok) throw new WhoopError(`Whoop token endpoint returned ${res.status}`, res.status);
  return (await res.json()) as WhoopTokens;
}

export function exchangeCode(
  fetchFn: Fetch,
  p: { code: string; clientId: string; clientSecret: string; redirectUri: string },
): Promise<WhoopTokens> {
  return postForm(fetchFn, {
    grant_type: "authorization_code",
    code: p.code,
    client_id: p.clientId,
    client_secret: p.clientSecret,
    redirect_uri: p.redirectUri,
  });
}

/** Whoop invalidates the old refresh token when this succeeds: always store the new pair. */
export function refreshTokens(
  fetchFn: Fetch,
  p: { refreshToken: string; clientId: string; clientSecret: string },
): Promise<WhoopTokens> {
  return postForm(fetchFn, {
    grant_type: "refresh_token",
    refresh_token: p.refreshToken,
    client_id: p.clientId,
    client_secret: p.clientSecret,
    scope: "offline",
  });
}

async function getJSON<T>(fetchFn: Fetch, accessToken: string, path: string, query: Record<string, string> = {}): Promise<T> {
  const url = new URL(WHOOP_API_BASE + path);
  for (const [k, v] of Object.entries(query)) url.searchParams.set(k, v);
  const res = await fetchFn(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (!res.ok) throw new WhoopError(`Whoop ${path} returned ${res.status}`, res.status);
  return (await res.json()) as T;
}

async function collect<T>(fetchFn: Fetch, accessToken: string, path: string, start: Date, end: Date): Promise<T[]> {
  const records: T[] = [];
  let nextToken: string | undefined;
  // 25 per page is Whoop's max; 30 days fits in two pages, the cap guards against loops.
  for (let page = 0; page < 20; page++) {
    const query: Record<string, string> = { limit: "25", start: start.toISOString(), end: end.toISOString() };
    if (nextToken) query.nextToken = nextToken;
    const body = await getJSON<{ records: T[]; next_token?: string | null }>(fetchFn, accessToken, path, query);
    records.push(...body.records);
    if (!body.next_token) break;
    nextToken = body.next_token;
  }
  return records;
}

export function listSleeps(fetchFn: Fetch, accessToken: string, start: Date, end: Date): Promise<WhoopSleep[]> {
  return collect<WhoopSleep>(fetchFn, accessToken, "/v2/activity/sleep", start, end);
}

export function listRecoveries(fetchFn: Fetch, accessToken: string, start: Date, end: Date): Promise<WhoopRecovery[]> {
  return collect<WhoopRecovery>(fetchFn, accessToken, "/v2/recovery", start, end);
}

export function listCycles(fetchFn: Fetch, accessToken: string, start: Date, end: Date): Promise<WhoopCycle[]> {
  return collect<WhoopCycle>(fetchFn, accessToken, "/v2/cycle", start, end);
}

export function getProfile(fetchFn: Fetch, accessToken: string): Promise<{ user_id: number }> {
  return getJSON(fetchFn, accessToken, "/v2/user/profile/basic");
}
