import i18next from "i18next";
import { describe, expect, test } from "vitest";
import { recordRequests } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";
import { api, setCsrfToken, withCsrf } from "./client";

const url = "http://localhost/api/v1/example";
const SPEC_TOKEN = "SXlPVEZ3Zm9MUw4JHQ0rNTI8KyorFxUZ"; // get_browser_csrf_token's example

describe("withCsrf", () => {
  test("adds the session's token to state-changing requests", () => {
    setCsrfToken("token-from-session");
    for (const method of ["POST", "PUT", "DELETE"]) {
      expect(withCsrf(new Request(url, { method })).headers.get("X-CSRF-Token")).toBe("token-from-session");
    }
  });

  test("leaves reads alone", () => {
    setCsrfToken("token-from-session");
    expect(withCsrf(new Request(url, { method: "GET" })).headers.get("X-CSRF-Token")).toBeNull();
  });

  test("sends nothing before a token is known", () => {
    expect(withCsrf(new Request(url, { method: "POST" })).headers.get("X-CSRF-Token")).toBeNull();
  });
});

describe("api session handling", () => {
  test("a write fetches the CSRF token first, then sends it", async () => {
    server.use(specHandler("get_browser_csrf_token", 200), specHandler("resend_verification_code", 202));
    const requests = recordRequests();

    const { response } = await api.POST("/api/v1/accounts/resend_verification_code", {
      body: { email: "amina@example.com" },
    });

    expect(response.status).toBe(202);
    expect(requests.map((request) => `${request.method} ${request.path}`)).toEqual([
      "GET /api/v1/browser/csrf_token",
      "POST /api/v1/accounts/resend_verification_code",
    ]);
    expect(requests[1]?.headers.get("X-CSRF-Token")).toBe(SPEC_TOKEN);
  });

  test("reads never fetch a token", async () => {
    server.use(specHandler("get_current_account", 200));
    const requests = recordRequests();

    await api.GET("/api/v1/account");

    expect(requests.map((request) => request.path)).toEqual(["/api/v1/account"]);
    expect(requests[0]?.headers.get("X-CSRF-Token")).toBeNull();
  });

  test("csrf_token_invalid refetches the token once and retries the same request", async () => {
    setCsrfToken("stale-token");
    server.use(
      specProblem("delete_browser_session", "csrf_token_invalid", { once: true }),
      specHandler("delete_browser_session", 204),
      specHandler("get_browser_csrf_token", 200),
    );
    const requests = recordRequests();

    const { response } = await api.DELETE("/api/v1/browser/session");

    expect(response.status).toBe(204);
    expect(requests.map((request) => `${request.method} ${request.headers.get("X-CSRF-Token") ?? "-"}`)).toEqual([
      "DELETE stale-token",
      "GET -",
      `DELETE ${SPEC_TOKEN}`,
    ]);
  });

  test("a second csrf_token_invalid is returned, not retried again", async () => {
    setCsrfToken("stale-token");
    server.use(specProblem("delete_browser_session", "csrf_token_invalid"), specHandler("get_browser_csrf_token", 200));
    const requests = recordRequests();

    const { response, error } = await api.DELETE("/api/v1/browser/session");

    expect(response.status).toBe(403);
    expect(error).toMatchObject({ code: "csrf_token_invalid" });
    expect(requests).toHaveLength(3);
  });

  test("Accept-Language follows the UI language", async () => {
    server.use(specHandler("get_browser_csrf_token", 200), specHandler("request_password_reset", 202));
    const requests = recordRequests();
    await i18next.changeLanguage("ar");

    await api.POST("/api/v1/accounts/request_password_reset", { body: { email: "amina@example.com" } });

    expect(requests.at(-1)?.headers.get("Accept-Language")).toBe("ar");
  });
});
