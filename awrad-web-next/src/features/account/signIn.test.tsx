import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, test } from "vitest";
import { setCsrfToken } from "@/shared/api/client";
import { recordRequests, renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";
import { forgetPending } from "./pending";

const SPEC_TOKEN = "SXlPVEZ3Zm9MUw4JHQ0rNTI8KyorFxUZ";

async function signIn(email: string, password: string) {
  await userEvent.type(await screen.findByLabelText("Email"), email);
  await userEvent.type(screen.getByLabelText("Password"), password);
  await userEvent.click(screen.getByRole("button", { name: "Sign in" }));
}

describe("sign in", () => {
  afterEach(() => {
    forgetPending();
  });

  test("signs in, replaces the CSRF token with the one sign-in returns, and signs out with it", async () => {
    setCsrfToken("anonymous-token");
    server.use(
      specHandler("create_browser_session", 200),
      specHandler("get_current_account", 200),
      specHandler("delete_browser_session", 204),
    );
    const requests = recordRequests();
    renderRoute("/sign-in");

    await signIn("  amina@example.com ", "a long passphrase");

    expect(await screen.findByRole("heading", { name: "Your account" })).toBeInTheDocument();
    expect(screen.getByText("amina@example.com")).toBeInTheDocument();
    const create = requests.find((request) => request.method === "POST");
    expect(create?.body).toEqual({ email: "amina@example.com", password: "a long passphrase", remember_me: true });
    expect(create?.headers.get("X-CSRF-Token")).toBe("anonymous-token");
    expect(create?.headers.get("Idempotency-Key")).toMatch(/^[0-9a-f-]{36}$/);

    server.use(specProblem("get_current_account", "unauthenticated"));
    await userEvent.click(screen.getByRole("button", { name: "Sign out" }));

    expect(await screen.findByText(/Sign in to use your Awrad account/)).toBeInTheDocument();
    const remove = requests.find((request) => request.method === "DELETE");
    expect(remove?.headers.get("X-CSRF-Token")).toBe(SPEC_TOKEN);
  });

  test("a wrong email or password is explained by its code", async () => {
    server.use(
      specHandler("get_browser_csrf_token", 200),
      specProblem("create_browser_session", "invalid_credentials"),
    );
    renderRoute("/sign-in");

    await signIn("amina@example.com", "not the password");

    expect(await screen.findByRole("alert")).toHaveTextContent("That email and password don't match an account.");
  });

  test("an unverified email goes to the code screen, which then signs in with the same password", async () => {
    server.use(
      specHandler("get_browser_csrf_token", 200),
      specProblem("create_browser_session", "email_verification_required", { once: true }),
      specHandler("verify_account_email", 204),
      specHandler("create_browser_session", 200),
      specHandler("get_current_account", 200),
    );
    const requests = recordRequests();
    renderRoute("/sign-in");

    await signIn("amina@example.com", "a long passphrase");

    expect(await screen.findByRole("heading", { name: "Verify your email" })).toBeInTheDocument();
    expect(screen.getByText("amina@example.com")).toBeInTheDocument();
    await userEvent.type(screen.getByLabelText("6-digit code"), "482 913");
    await userEvent.click(screen.getByRole("button", { name: "Verify" }));

    expect(await screen.findByRole("heading", { name: "Your account" })).toBeInTheDocument();
    const sessions = requests.filter((request) => request.path === "/api/v1/browser/session");
    expect(sessions.map((request) => request.body)).toEqual([
      { email: "amina@example.com", password: "a long passphrase", remember_me: true },
      { email: "amina@example.com", password: "a long passphrase", remember_me: true },
    ]);
  });

  test("checks the form before sending anything", async () => {
    const requests = recordRequests();
    renderRoute("/sign-in");

    await userEvent.type(await screen.findByLabelText("Email"), "amina@localhost");
    await userEvent.click(screen.getByRole("button", { name: "Sign in" }));

    expect(await screen.findByText("Enter a valid email address.")).toBeInTheDocument();
    expect(screen.getByText("Enter your password.")).toBeInTheDocument();
    expect(screen.getByLabelText("Email")).toHaveAttribute("aria-invalid", "true");
    expect(requests).toHaveLength(0);
  });

  test("rate limiting is explained", async () => {
    server.use(specHandler("get_browser_csrf_token", 200), specProblem("create_browser_session", "rate_limited"));
    renderRoute("/sign-in");

    await signIn("amina@example.com", "a long passphrase");

    expect(await screen.findByRole("alert")).toHaveTextContent("Too many attempts.");
  });
});
