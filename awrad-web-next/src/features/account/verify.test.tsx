import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, test } from "vitest";
import { recordRequests, renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";
import { forgetPending, rememberPending } from "./pending";

describe("verify email", () => {
  afterEach(() => {
    forgetPending();
  });

  test("a wrong code is explained, and no sign-in is tried", async () => {
    rememberPending({ email: "amina@example.com", password: "a long passphrase" });
    server.use(
      specHandler("get_browser_csrf_token", 200),
      specProblem("verify_account_email", "verification_code_invalid"),
    );
    const requests = recordRequests();
    renderRoute("/verify-email");

    await userEvent.type(await screen.findByLabelText("6-digit code"), "000000");
    await userEvent.click(screen.getByRole("button", { name: "Verify" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("That code is wrong or has expired.");
    expect(requests.some((request) => request.path === "/api/v1/browser/session")).toBe(false);
  });

  test("right after a code was sent, resending waits a minute", async () => {
    rememberPending({ email: "amina@example.com", password: "a long passphrase" });
    renderRoute("/verify-email");

    expect(await screen.findByRole("button", { name: "Send a new code" })).toBeDisabled();
    expect(screen.getByText("You can ask for a new code in 60 s.")).toBeInTheDocument();
  });

  test("after a reload it asks for the email, resends, then waits", async () => {
    server.use(specHandler("get_browser_csrf_token", 200), specHandler("resend_verification_code", 202));
    const requests = recordRequests();
    renderRoute("/verify-email");

    await userEvent.type(await screen.findByLabelText("Email"), "amina@example.com ");
    await userEvent.click(screen.getByRole("button", { name: "Send a new code" }));

    expect(await screen.findByRole("status")).toHaveTextContent("A new code is on its way.");
    expect(screen.getByRole("button", { name: "Send a new code" })).toBeDisabled();
    expect(requests.at(-1)?.body).toEqual({ email: "amina@example.com" });
  });

  test("a rate-limited resend waits for the server's Retry-After", async () => {
    server.use(specHandler("get_browser_csrf_token", 200), specProblem("resend_verification_code", "rate_limited"));
    renderRoute("/verify-email");

    await userEvent.type(await screen.findByLabelText("Email"), "amina@example.com");
    await userEvent.click(screen.getByRole("button", { name: "Send a new code" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Too many attempts.");
    // The spec's Retry-After example is 30 seconds.
    expect(screen.getByText("You can ask for a new code in 30 s.")).toBeInTheDocument();
  });

  test("without a remembered password, verifying sends the person to sign in", async () => {
    server.use(specHandler("get_browser_csrf_token", 200), specHandler("verify_account_email", 204));
    renderRoute("/verify-email");

    await userEvent.type(await screen.findByLabelText("Email"), "amina@example.com");
    await userEvent.type(screen.getByLabelText("6-digit code"), "４８２９１３");
    await userEvent.click(screen.getByRole("button", { name: "Verify" }));

    expect(await screen.findByRole("status")).toHaveTextContent("Your email is verified.");
    expect(screen.getByRole("heading", { name: "Sign in" })).toBeInTheDocument();
    expect(screen.getByLabelText("Email")).toHaveValue("amina@example.com");
  });
});
