import createClient, { type Middleware } from "openapi-fetch";
import type { paths } from "./schema.gen";

const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);
let csrfToken: string | null = null;

/** Remembers the session's CSRF token (from `get_browser_csrf_token`) for later writes. */
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

const csrf: Middleware = {
  onRequest: ({ request }) => withCsrf(request),
};

/**
 * The only way the app talks to the network. Types come from
 * contracts/api/openapi.bundled.json, so a route or field that isn't in the
 * spec doesn't compile. Same origin as the page, so the session cookie is sent.
 */
export const api = createClient<paths>({
  baseUrl: window.location.origin,
  credentials: "same-origin",
  // Look up fetch on every call rather than once at module load, so anything that
  // wraps fetch later (test mocks, instrumentation) is honoured.
  fetch: (request) => globalThis.fetch(request),
});
api.use(csrf);
