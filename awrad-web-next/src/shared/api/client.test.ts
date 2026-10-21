import { afterEach, describe, expect, test } from "vitest";
import { setCsrfToken, withCsrf } from "./client";

const url = "http://localhost/api/v1/example";

describe("withCsrf", () => {
  afterEach(() => {
    setCsrfToken(null);
  });

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
