import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, test } from "vitest";
import i18next from "i18next";
import { server } from "@/test/setup";
import { renderWithQuery } from "@/test/render";
import { specHandler } from "@/test/spec";
import { WelcomePage } from "./WelcomePage";

describe("WelcomePage", () => {
  afterEach(async () => {
    await i18next.changeLanguage("en");
  });

  test("a 401 unauthenticated problem shows the signed-out state", async () => {
    server.use(specHandler("get_browser_csrf_token", 401));
    renderWithQuery(<WelcomePage />);

    expect(await screen.findByText(/You're not signed in/)).toBeInTheDocument();
  });

  test("a 200 shows the signed-in state", async () => {
    server.use(specHandler("get_browser_csrf_token", 200));
    renderWithQuery(<WelcomePage />);

    expect(await screen.findByText("You're signed in.")).toBeInTheDocument();
  });

  test("choosing Arabic translates the page and switches it to right-to-left", async () => {
    server.use(specHandler("get_browser_csrf_token", 401));
    renderWithQuery(<WelcomePage />);

    await userEvent.click(screen.getByRole("button", { name: "العربية" }));

    expect(await screen.findByRole("heading", { name: "السلام عليكم" })).toBeInTheDocument();
    expect(document.documentElement).toHaveAttribute("dir", "rtl");
    expect(document.documentElement).toHaveAttribute("lang", "ar");
  });
});
