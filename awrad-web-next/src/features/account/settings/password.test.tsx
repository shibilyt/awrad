import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, test } from "vitest";
import { recordRequests, renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";

function signedIn() {
  server.use(specHandler("get_current_account", 200), specHandler("get_browser_csrf_token", 200));
}

async function changePassword(current: string, next: string) {
  await userEvent.type(await screen.findByLabelText("Current password"), current);
  await userEvent.type(screen.getByLabelText("New password"), next);
  await userEvent.click(screen.getByRole("button", { name: "Change password" }));
}

describe("change password", () => {
  test("the account page links to it, and it explains what happens", async () => {
    signedIn();
    renderRoute("/account");

    await userEvent.click(await screen.findByRole("link", { name: "Change password" }));

    expect(await screen.findByRole("heading", { name: "Change password" })).toBeInTheDocument();
    expect(screen.getByText(/signs you out on every other device and browser/)).toBeInTheDocument();
    expect(screen.getByLabelText("New password")).toHaveAccessibleDescription(
      "At least 12 characters. A few words you'll remember work well.",
    );
  });

  test("changes it, then the account page says other devices are signed out", async () => {
    signedIn();
    server.use(specHandler("change_password", 204));
    const requests = recordRequests();
    renderRoute("/account/password");

    await changePassword("a long passphrase", "another long passphrase");

    expect(await screen.findByRole("status")).toHaveTextContent("Your password is changed.");
    expect(screen.getByRole("heading", { name: "Your account" })).toBeInTheDocument();
    const change = requests.find((request) => request.method === "POST");
    expect(change?.body).toEqual({ current_password: "a long passphrase", new_password: "another long passphrase" });
    expect(change?.headers.get("Idempotency-Key")).toMatch(/^[0-9a-f-]{36}$/);
  });

  test("a wrong current password is shown on that field", async () => {
    signedIn();
    server.use(specProblem("change_password", "validation_failed"));
    renderRoute("/account/password");

    await changePassword("not my password", "another long passphrase");

    expect(await screen.findByLabelText("Current password")).toHaveAccessibleDescription(
      "That isn't your current password.",
    );
    expect(screen.getByRole("alert")).toHaveTextContent("Check the highlighted fields.");
  });

  test("a short new password is stopped before sending", async () => {
    signedIn();
    const requests = recordRequests();
    renderRoute("/account/password");

    await changePassword("a long passphrase", "too short");

    expect(await screen.findByText("Use at least 12 characters.")).toBeInTheDocument();
    expect(requests.some((request) => request.method === "POST")).toBe(false);
  });

  test("the current password is required", async () => {
    signedIn();
    renderRoute("/account/password");

    await userEvent.type(await screen.findByLabelText("New password"), "another long passphrase");
    await userEvent.click(screen.getByRole("button", { name: "Change password" }));

    expect(await screen.findByText("Enter your current password.")).toBeInTheDocument();
  });

  test("rate limited is explained", async () => {
    signedIn();
    server.use(specProblem("change_password", "rate_limited"));
    renderRoute("/account/password");

    await changePassword("a long passphrase", "another long passphrase");

    expect(await screen.findByRole("alert")).toHaveTextContent("Too many attempts.");
  });
});
