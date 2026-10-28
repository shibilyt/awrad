import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { setCsrfToken } from "@/shared/api/client";
import type { components } from "@/shared/api/schema.gen";
import { recordRequests, renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";

interface SessionPage {
  items: components["schemas"]["AccountSession"][];
}

const SPEC_TOKEN = "SXlPVEZ3Zm9MUw4JHQ0rNTI8KyorFxUZ"; // get_browser_csrf_token's example
const FIREFOX_ID = "4c2e8f10-7b3a-4d5e-9f61-2a8b0c1d3e45"; // list_account_sessions' browser session

function signedIn() {
  server.use(
    specHandler("get_current_account", 200),
    specHandler("get_browser_csrf_token", 200),
    specHandler("list_account_sessions", 200),
  );
}

async function openDevices() {
  renderRoute("/account/devices");
  return screen.findByRole("list", { name: "Signed-in devices" });
}

beforeEach(() => {
  // Only Date: an hour after the example's phone was last used.
  vi.useFakeTimers({ toFake: ["Date"], now: new Date("2026-10-27T07:40:00Z") });
});
afterEach(() => {
  vi.useRealTimers();
});

describe("device list", () => {
  test("lists phones and browsers with this one marked, platform and last use", async () => {
    signedIn();
    const list = await openDevices();

    const [phone, browser] = within(list).getAllByRole("listitem");
    expect(phone).toHaveTextContent("Pixel 9");
    expect(phone).toHaveTextContent("This device");
    expect(phone).toHaveTextContent("Android · Last used 1 hour ago");
    expect(within(phone ?? list).queryByRole("button")).toBeNull();
    expect(browser).toHaveTextContent("Firefox on Windows");
    expect(browser).toHaveTextContent("Web · Last used 10 hours ago");
    expect(within(browser ?? list).getByRole("button", { name: "Sign out Firefox on Windows" })).toBeInTheDocument();
  });

  test("in Arabic the list is translated and right-to-left", async () => {
    signedIn();
    await openDevices();

    await userEvent.click(screen.getByRole("button", { name: "العربية" }));

    expect(await screen.findByRole("heading", { name: "الأجهزة" })).toBeInTheDocument();
    expect(screen.getByText("هذا الجهاز")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "تسجيل خروج Firefox on Windows" })).toBeInTheDocument();
    expect(document.documentElement).toHaveAttribute("dir", "rtl");
  });

  test("a browser the server couldn't name is a generic web browser", async () => {
    // The spec example has one browser with a null name, next to a named one.
    signedIn();
    const list = await openDevices();

    expect(within(list).getAllByText("Web browser")).toHaveLength(1);
    expect(within(list).getByText("Firefox on Windows")).toBeInTheDocument();
  });

  test("alone on the account, there's nothing else to sign out", async () => {
    signedIn();
    server.use(
      specHandler("list_account_sessions", 200, {
        from: (page: SessionPage) => ({ ...page, items: page.items.filter((item) => item.is_current) }),
      }),
    );
    await openDevices();

    expect(screen.getByText("Your account isn't signed in anywhere else.")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Sign out of all other devices" })).toBeNull();
  });
});

describe("signing devices out", () => {
  test("signing out one device asks first, then revokes it and refreshes the list", async () => {
    signedIn();
    server.use(specHandler("revoke_account_session", 204));
    const requests = recordRequests();
    await openDevices();

    await userEvent.click(screen.getByRole("button", { name: "Sign out Firefox on Windows" }));
    const dialog = await screen.findByRole("alertdialog", { name: "Sign out Firefox on Windows?" });
    await userEvent.click(within(dialog).getByRole("button", { name: "Sign out" }));

    expect(await screen.findByRole("status")).toHaveTextContent("Firefox on Windows is signed out.");
    expect(screen.queryByRole("alertdialog")).toBeNull();
    const revoke = requests.find((request) => request.method === "DELETE");
    expect(revoke?.path).toBe(`/api/v1/account/sessions/${FIREFOX_ID}`);
    expect(revoke?.headers.get("X-CSRF-Token")).toBe(SPEC_TOKEN);
    await vi.waitFor(() => {
      expect(requests.filter((request) => request.path === "/api/v1/account/sessions")).toHaveLength(2);
    });
  });

  test("cancelling the confirmation sends nothing", async () => {
    signedIn();
    const requests = recordRequests();
    await openDevices();

    await userEvent.click(screen.getByRole("button", { name: "Sign out Firefox on Windows" }));
    const dialog = await screen.findByRole("alertdialog");
    await userEvent.click(within(dialog).getByRole("button", { name: "Cancel" }));

    expect(screen.queryByRole("alertdialog")).toBeNull();
    expect(requests.some((request) => request.method === "DELETE")).toBe(false);
  });

  test("a device that had already gone is a notice, not an error", async () => {
    signedIn();
    server.use(specProblem("revoke_account_session", "not_found"));
    await openDevices();

    await userEvent.click(screen.getByRole("button", { name: "Sign out Firefox on Windows" }));
    await userEvent.click(within(await screen.findByRole("alertdialog")).getByRole("button", { name: "Sign out" }));

    expect(await screen.findByRole("status")).toHaveTextContent("That device was already signed out.");
    expect(screen.queryByRole("alert")).toBeNull();
  });

  test("signing out of all other devices keeps this one", async () => {
    signedIn();
    server.use(specHandler("revoke_other_account_sessions", 204));
    const requests = recordRequests();
    await openDevices();

    await userEvent.click(screen.getByRole("button", { name: "Sign out of all other devices" }));
    const dialog = await screen.findByRole("alertdialog", { name: "Sign out of all other devices?" });
    expect(dialog).toHaveTextContent("This one stays signed in.");
    await userEvent.click(within(dialog).getByRole("button", { name: "Sign out of all other devices" }));

    expect(await screen.findByRole("status")).toHaveTextContent("Every other device is signed out.");
    const revoke = requests.find((request) => request.path === "/api/v1/account/sessions/revoke_others");
    expect(revoke?.method).toBe("POST");
    expect(revoke?.headers.get("Idempotency-Key")).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
  });

  test("a stale CSRF token is refreshed once and the same request retried", async () => {
    signedIn();
    setCsrfToken("stale-token");
    server.use(
      specProblem("revoke_other_account_sessions", "csrf_token_invalid", { once: true }),
      specHandler("revoke_other_account_sessions", 204),
    );
    const requests = recordRequests();
    await openDevices();

    await userEvent.click(screen.getByRole("button", { name: "Sign out of all other devices" }));
    const dialog = await screen.findByRole("alertdialog");
    await userEvent.click(within(dialog).getByRole("button", { name: "Sign out of all other devices" }));

    expect(await screen.findByRole("status")).toHaveTextContent("Every other device is signed out.");
    const writes = requests.filter((request) => request.method !== "GET" || request.path.endsWith("csrf_token"));
    expect(writes.map((request) => `${request.method} ${request.headers.get("X-CSRF-Token") ?? "-"}`)).toEqual([
      "POST stale-token",
      "GET -",
      `POST ${SPEC_TOKEN}`,
    ]);
    expect(writes[2]?.headers.get("Idempotency-Key")).toBe(writes[0]?.headers.get("Idempotency-Key"));
  });
});
