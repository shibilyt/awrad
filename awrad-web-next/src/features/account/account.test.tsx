import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, test } from "vitest";
import { renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";

describe("home and account page", () => {
  test("signed out, home offers sign in and registration", async () => {
    server.use(specProblem("get_current_account", "unauthenticated"));
    renderRoute("/");

    expect(await screen.findByRole("link", { name: "Sign in" })).toHaveAttribute("href", "/sign-in");
    expect(screen.getByRole("link", { name: "Create an account" })).toHaveAttribute("href", "/register");
  });

  test("signed in, home shows the account's email", async () => {
    server.use(specHandler("get_current_account", 200));
    renderRoute("/");

    expect(await screen.findByText("amina@example.com")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Your account" })).toHaveAttribute("href", "/account");
  });

  test("signed out, the account page goes to sign in", async () => {
    server.use(specProblem("get_current_account", "unauthenticated"));
    renderRoute("/account");

    expect(await screen.findByRole("heading", { name: "Sign in" })).toBeInTheDocument();
  });

  test("signing out a session that already ended still signs out", async () => {
    server.use(
      specHandler("get_current_account", 200),
      specHandler("get_browser_csrf_token", 200),
      specProblem("delete_browser_session", "unauthenticated"),
    );
    renderRoute("/account");
    const signOut = await screen.findByRole("button", { name: "Sign out" });

    server.use(specProblem("get_current_account", "unauthenticated"));
    await userEvent.click(signOut);

    expect(await screen.findByRole("link", { name: "Sign in" })).toBeInTheDocument();
  });

  test("Arabic translates the app and switches it to right-to-left", async () => {
    server.use(specProblem("get_current_account", "unauthenticated"));
    renderRoute("/sign-in");

    await userEvent.click(await screen.findByRole("button", { name: "العربية" }));

    expect(await screen.findByRole("heading", { name: "تسجيل الدخول" })).toBeInTheDocument();
    expect(screen.getByLabelText("البريد الإلكتروني")).toBeInTheDocument();
    expect(document.documentElement).toHaveAttribute("dir", "rtl");
    expect(document.documentElement).toHaveAttribute("lang", "ar");
  });
});
