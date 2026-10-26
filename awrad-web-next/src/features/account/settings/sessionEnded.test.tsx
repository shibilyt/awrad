import type { QueryClient } from "@tanstack/react-query";
import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, test } from "vitest";
import { renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";

const ENDED = "Your session has ended, maybe because you signed out on another device. Sign in again.";

function cache(router: ReturnType<typeof renderRoute>["router"]): QueryClient {
  return router.options.context.queryClient;
}

describe("a session that ended meanwhile", () => {
  test("a 401 loading the devices signs out with a message and drops the account's data", async () => {
    server.use(specHandler("get_current_account", 200), specProblem("list_account_sessions", "unauthenticated"));
    const { router } = renderRoute("/account/devices");

    expect(await screen.findByRole("heading", { name: "Sign in" })).toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveTextContent(ENDED);
    expect(cache(router).getQueryData(["account", "current"])).toBeNull();
    expect(cache(router).getQueryData(["account", "sessions"])).toBeUndefined();
  });

  test("a 401 on a change signs out with a message", async () => {
    server.use(
      specHandler("get_current_account", 200),
      specHandler("get_browser_csrf_token", 200),
      specHandler("list_account_sessions", 200),
      specProblem("revoke_account_session", "unauthenticated"),
    );
    const { router } = renderRoute("/account/devices");

    await userEvent.click(await screen.findByRole("button", { name: "Sign out Firefox on Windows" }));
    await userEvent.click(within(await screen.findByRole("alertdialog")).getByRole("button", { name: "Sign out" }));

    expect(await screen.findByRole("heading", { name: "Sign in" })).toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveTextContent(ENDED);
    expect(cache(router).getQueryData(["account", "sessions"])).toBeUndefined();
  });

  test("a 401 on a form signs out with a message instead of a form error", async () => {
    server.use(
      specHandler("get_current_account", 200),
      specHandler("get_browser_csrf_token", 200),
      specProblem("change_password", "unauthenticated"),
    );
    renderRoute("/account/password");

    await userEvent.type(await screen.findByLabelText("Current password"), "a long passphrase");
    await userEvent.type(screen.getByLabelText("New password"), "another long passphrase");
    await userEvent.click(screen.getByRole("button", { name: "Change password" }));

    expect(await screen.findByRole("heading", { name: "Sign in" })).toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveTextContent(ENDED);
  });
});
