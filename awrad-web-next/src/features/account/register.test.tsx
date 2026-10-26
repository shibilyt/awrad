import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, test } from "vitest";
import { recordRequests, renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler } from "@/test/spec";
import { forgetPending } from "./pending";

async function register(email: string, password: string) {
  await userEvent.type(await screen.findByLabelText("Email"), email);
  await userEvent.type(screen.getByLabelText("Password"), password);
  await userEvent.click(screen.getByRole("button", { name: "Create account" }));
}

describe("register", () => {
  afterEach(() => {
    forgetPending();
  });

  test("register, verify with Arabic-Indic digits, and land signed in", async () => {
    server.use(
      specHandler("get_browser_csrf_token", 200),
      specHandler("register_account", 202),
      specHandler("verify_account_email", 204),
      specHandler("create_browser_session", 200),
      specHandler("get_current_account", 200),
    );
    const requests = recordRequests();
    renderRoute("/register");

    await register("amina@example.com", "dhikr every morning");
    expect(await screen.findByRole("heading", { name: "Verify your email" })).toBeInTheDocument();
    await userEvent.type(screen.getByLabelText("6-digit code"), "٤٨٢-٩١٣");
    await userEvent.click(screen.getByRole("button", { name: "Verify" }));

    expect(await screen.findByRole("heading", { name: "Your account" })).toBeInTheDocument();
    const posts = requests.filter((request) => request.method === "POST");
    expect(posts.map((request) => [request.path, request.body])).toEqual([
      ["/api/v1/accounts", { email: "amina@example.com", password: "dhikr every morning" }],
      ["/api/v1/accounts/verify_email", { email: "amina@example.com", code: "482913" }],
      ["/api/v1/browser/session", { email: "amina@example.com", password: "dhikr every morning", remember_me: true }],
    ]);
    expect(posts[0]?.headers.get("Accept-Language")).toBe("en");
  });

  test("shows the 12-character hint and checks length in code points before sending", async () => {
    const requests = recordRequests();
    renderRoute("/register");

    expect(await screen.findByLabelText("Password")).toHaveAccessibleDescription(/At least 12 characters/);
    // 6 emoji are 12 UTF-16 units but 6 code points: too short.
    await register("amina@example.com", "😀😀😀😀😀😀");

    expect(await screen.findByText("Use at least 12 characters.")).toBeInTheDocument();
    expect(screen.getByRole("alert")).toHaveTextContent("Check the highlighted fields.");
    expect(requests).toHaveLength(0);
  });

  test("the server's field codes land on their inputs", async () => {
    server.use(specHandler("get_browser_csrf_token", 200), specHandler("register_account", 422));
    renderRoute("/register");

    await register("amina@example.com", "a long passphrase");

    expect(await screen.findByText("Use at least 12 characters.")).toBeInTheDocument();
    expect(screen.getByLabelText("Password")).toHaveAttribute("aria-invalid", "true");
    expect(screen.getByLabelText("Email")).not.toHaveAttribute("aria-invalid");
  });
});
