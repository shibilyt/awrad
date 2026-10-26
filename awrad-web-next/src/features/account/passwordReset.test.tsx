import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, test } from "vitest";
import { recordRequests, renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";
import { forgetPending } from "./pending";

async function requestCode(email: string) {
  await userEvent.click(await screen.findByRole("link", { name: "Forgot your password?" }));
  await screen.findByRole("heading", { name: "Reset your password" });
  await userEvent.type(screen.getByLabelText("Email"), email);
  await userEvent.click(screen.getByRole("button", { name: "Send code" }));
  await screen.findByRole("heading", { name: "Choose a new password" });
}

describe("password reset", () => {
  afterEach(() => {
    forgetPending();
  });

  test("forgot, reset with the code, and land signed in with the new password", async () => {
    server.use(
      specHandler("get_browser_csrf_token", 200),
      specHandler("request_password_reset", 202),
      specHandler("reset_password", 204),
      specHandler("create_browser_session", 200),
      specHandler("get_current_account", 200),
    );
    const requests = recordRequests();
    renderRoute("/sign-in");

    await requestCode("amina@example.com");
    expect(screen.getByText("Changing your password signs you out on every device.")).toBeInTheDocument();
    await userEvent.type(screen.getByLabelText("6-digit code"), "730158");
    await userEvent.type(screen.getByLabelText("New password"), "another long passphrase");
    await userEvent.click(screen.getByRole("button", { name: "Set new password" }));

    expect(await screen.findByRole("heading", { name: "Your account" })).toBeInTheDocument();
    const posts = requests.filter((request) => request.method === "POST");
    expect(posts.map((request) => [request.path, request.body])).toEqual([
      ["/api/v1/accounts/request_password_reset", { email: "amina@example.com" }],
      [
        "/api/v1/accounts/reset_password",
        { email: "amina@example.com", code: "730158", new_password: "another long passphrase" },
      ],
      [
        "/api/v1/browser/session",
        { email: "amina@example.com", password: "another long passphrase", remember_me: true },
      ],
    ]);
  });

  test("a wrong reset code is explained", async () => {
    server.use(
      specHandler("get_browser_csrf_token", 200),
      specHandler("request_password_reset", 202),
      specProblem("reset_password", "reset_code_invalid"),
    );
    renderRoute("/sign-in");

    await requestCode("amina@example.com");
    await userEvent.type(screen.getByLabelText("6-digit code"), "730158");
    await userEvent.type(screen.getByLabelText("New password"), "another long passphrase");
    await userEvent.click(screen.getByRole("button", { name: "Set new password" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("That code is wrong or has expired.");
  });

  test("when signing in afterwards fails, it sends the person to sign in", async () => {
    server.use(
      specHandler("get_browser_csrf_token", 200),
      specHandler("request_password_reset", 202),
      specHandler("reset_password", 204),
      specProblem("create_browser_session", "rate_limited"),
    );
    renderRoute("/sign-in");

    await requestCode("amina@example.com");
    await userEvent.type(screen.getByLabelText("6-digit code"), "730158");
    await userEvent.type(screen.getByLabelText("New password"), "another long passphrase");
    await userEvent.click(screen.getByRole("button", { name: "Set new password" }));

    expect(await screen.findByRole("status")).toHaveTextContent("Your password is changed.");
    expect(screen.getByLabelText("Email")).toHaveValue("amina@example.com");
  });
});
