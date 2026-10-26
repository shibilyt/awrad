import i18next from "i18next";
import createClient, { type Middleware } from "openapi-fetch";
import { isProblem } from "./problem";
import type { paths } from "./schema.gen";

const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);

/**
 * The session's CSRF token, in memory only (ADR-2026-10-15): never in
 * localStorage. It isn't a credential on its own; the httpOnly session cookie
 * is, and JavaScript never sees that.
 */
let csrfToken: string | null = null;
let loadingToken: Promise<void> | null = null;

/**
 * Remembers the session's CSRF token for later writes. Sign-in passes the token
 * `create_browser_session` returns (the session is renewed); sign-out passes
 * `null`, so the next write fetches a fresh one.
 */
export function setCsrfToken(token: string | null): void {
  csrfToken = token;
}

/** Adds `X-CSRF-Token` to a state-changing request (ADR-2026-10-15). Reads are left alone. */
export function withCsrf(request: Request): Request {
  if (!SAFE_METHODS.has(request.method) && csrfToken !== null) {
    request.headers.set("X-CSRF-Token", csrfToken);
  }
  return request;
}

/** Fetches the token from `get_browser_csrf_token`, once even when several writes ask together. */
function loadCsrfToken(): Promise<void> {
  loadingToken ??= api
    .GET("/api/v1/browser/csrf_token")
    .then(({ data }) => {
      // A 401 or a failure leaves no token: the write goes without one and the
      // server's answer (csrf_token_invalid, or the network error) is the result.
      setCsrfToken(data?.csrf_token ?? null);
    })
    .catch(() => {
      setCsrfToken(null);
    })
    .finally(() => {
      loadingToken = null;
    });
  return loadingToken;
}

async function isCsrfRejection(response: Response): Promise<boolean> {
  if (response.status !== 403) return false;
  try {
    const body: unknown = await response.clone().json();
    return isProblem(body) && body.code === "csrf_token_invalid";
  } catch {
    return false;
  }
}

/**
 * Sends a request with the session's CSRF token. A write fetches the token
 * first if none is known yet, and on `403 csrf_token_invalid` (the session was
 * renewed or expired) refetches it once and retries the same request, with the
 * same `Idempotency-Key`.
 */
async function sessionFetch(request: Request): Promise<Response> {
  // Look up fetch on every call rather than once at module load, so anything that
  // wraps fetch later (test mocks, instrumentation) is honoured.
  if (SAFE_METHODS.has(request.method)) return globalThis.fetch(request);
  if (csrfToken === null) await loadCsrfToken();
  const retry = request.clone();
  const response = await globalThis.fetch(withCsrf(request));
  if (!(await isCsrfRejection(response))) return response;
  setCsrfToken(null);
  await loadCsrfToken();
  return globalThis.fetch(withCsrf(retry));
}

/** `Accept-Language` follows the UI language, so emails the server sends match it. */
export function withLanguage(request: Request): Request {
  const language = i18next.resolvedLanguage ?? i18next.language;
  if (language) request.headers.set("Accept-Language", language);
  return request;
}

const language: Middleware = {
  onRequest: ({ request }) => withLanguage(request),
};

/**
 * The only way the app talks to the network. Types come from
 * contracts/api/openapi.bundled.json, so a route or field that isn't in the
 * spec doesn't compile. Same origin as the page, so the session cookie is sent.
 */
export const api = createClient<paths>({
  baseUrl: window.location.origin,
  credentials: "same-origin",
  fetch: sessionFetch,
});
api.use(language);

/** A fresh `Idempotency-Key` (STYLE §10) for one user action; a retry of it reuses the key. */
export function idempotencyKey(): string {
  return crypto.randomUUID();
}
