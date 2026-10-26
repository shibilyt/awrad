import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, test, vi } from "vitest";
import { recordRequests, renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";
import { forgetEmailChange, rememberEmailChange } from "./pendingEmailChange";

function signedIn() {
  server.use(specHandler("get_current_account", 200), specHandler("get_browser_csrf_token", 200));
}

async function enterCode(code: string) {
  await userEvent.type(await screen.findByLabelText("6-digit code"), code);
  await userEvent.click(screen.getByRole("button", { name: "Change email" }));
}

afterEach(() => {
  forgetEmailChange();
});

describe("change email", () => {
  test("password and new address, then the code sent to it, then the account shows the new email", async () => {
    signedIn();
    server.use(specHandler("request_email_change", 202), specHandler("confirm_email_change", 200));
    const requests = recordRequests();
    renderRoute("/account/email");

    expect(await screen.findByText("amina@example.com")).toBeInTheDocument();
    await userEvent.type(screen.getByLabelText("Current password"), "a long passphrase");
    await userEvent.type(screen.getByLabelText("New email"), " amina.new@example.com ");
    await userEvent.click(screen.getByRole("button", { name: "Send code" }));

    expect(await screen.findByRole("heading", { name: "Confirm your new email" })).toBeInTheDocument();
    expect(screen.getByText("amina.new@example.com")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Send a new code" })).toBeDisabled();
    expect(screen.getByText("You can ask for a new code in 60 s.")).toBeInTheDocument();

    await enterCode("519274");

    expect(await screen.findByRole("status")).toHaveTextContent("Your email is changed.");
    expect(screen.getByText("amina.new@example.com")).toBeInTheDocument();
    const posts = requests.filter((request) => request.method === "POST");
    expect(posts.map((request) => [request.path, request.body])).toEqual([
      [
        "/api/v1/account/request_email_change",
        { current_password: "a long passphrase", new_email: "amina.new@example.com" },
      ],
      ["/api/v1/account/confirm_email_change", { code: "519274" }],
    ]);
  });

  test("the same address as now is shown on the new email field", async () => {
    signedIn();
    server.use(specProblem("request_email_change", "validation_failed"));
    renderRoute("/account/email");

    await userEvent.type(await screen.findByLabelText("Current password"), "a long passphrase");
    await userEvent.type(screen.getByLabelText("New email"), "amina@example.com");
    await userEvent.click(screen.getByRole("button", { name: "Send code" }));

    expect(await screen.findByLabelText("New email")).toHaveAccessibleDescription(
      "That's already your account's email.",
    );
  });

  test("an invalid new address is stopped before sending", async () => {
    signedIn();
    const requests = recordRequests();
    renderRoute("/account/email");

    await userEvent.type(await screen.findByLabelText("Current password"), "a long passphrase");
    await userEvent.type(screen.getByLabelText("New email"), "not an email");
    await userEvent.click(screen.getByRole("button", { name: "Send code" }));

    expect(await screen.findByText("Enter a valid email address.")).toBeInTheDocument();
    expect(requests.some((request) => request.method === "POST")).toBe(false);
  });
});

describe("confirm the new email", () => {
  test("a wrong code is explained", async () => {
    signedIn();
    rememberEmailChange({ newEmail: "amina.new@example.com", currentPassword: "a long passphrase" });
    server.use(specProblem("confirm_email_change", "email_change_code_invalid"));
    renderRoute("/account/email/confirm");

    await enterCode("000000");

    expect(await screen.findByRole("alert")).toHaveTextContent("That code is wrong or has expired.");
  });

  test("409 email_taken: the address went to another account, so it starts again", async () => {
    signedIn();
    rememberEmailChange({ newEmail: "amina.new@example.com", currentPassword: "a long passphrase" });
    server.use(specProblem("confirm_email_change", "email_taken"));
    renderRoute("/account/email/confirm");

    await enterCode("519274");

    expect(await screen.findByRole("alert")).toHaveTextContent("That email now belongs to another account.");
    expect(screen.queryByRole("button", { name: "Send a new code" })).toBeNull();
    await userEvent.click(screen.getByRole("link", { name: "Use a different email" }));
    expect(await screen.findByRole("heading", { name: "Change email" })).toBeInTheDocument();
  });

  test("a new code asks again with the same password and address", async () => {
    signedIn();
    rememberEmailChange({ newEmail: "amina.new@example.com", currentPassword: "a long passphrase" });
    server.use(specHandler("request_email_change", 202));
    const requests = recordRequests();
    vi.useFakeTimers({ toFake: ["Date"] });
    try {
      renderRoute("/account/email/confirm");
      const resend = await screen.findByRole("button", { name: "Send a new code" });
      expect(resend).toBeDisabled();

      // A minute later (the countdown ticks on real timers and reads the clock).
      vi.setSystemTime(Date.now() + 61_000);
      await vi.waitFor(
        () => {
          expect(resend).toBeEnabled();
        },
        { timeout: 3000 },
      );
      await userEvent.click(resend);

      expect(await screen.findByRole("status")).toHaveTextContent("A new code is on its way.");
      expect(requests.find((request) => request.method === "POST")?.body).toEqual({
        current_password: "a long passphrase",
        new_email: "amina.new@example.com",
      });
    } finally {
      vi.useRealTimers();
    }
  });

  test("after a reload the code still works, without a resend", async () => {
    signedIn();
    server.use(specHandler("confirm_email_change", 200));
    renderRoute("/account/email/confirm");

    expect(await screen.findByText("Enter the 6-digit code we sent to your new email.")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Send a new code" })).toBeNull();
    await enterCode("519274");

    expect(await screen.findByRole("status")).toHaveTextContent("Your email is changed.");
  });
});
