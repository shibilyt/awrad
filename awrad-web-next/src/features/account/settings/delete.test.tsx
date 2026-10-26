import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, test } from "vitest";
import { recordRequests, renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";

function signedIn() {
  server.use(specHandler("get_current_account", 200), specHandler("get_browser_csrf_token", 200));
}

async function askToDelete(password: string) {
  await userEvent.type(await screen.findByLabelText("Current password"), password);
  await userEvent.click(screen.getByRole("button", { name: "Delete account" }));
  return screen.findByRole("alertdialog", { name: "Delete your account?" });
}

describe("delete account", () => {
  test("explains what happens before asking for anything", async () => {
    signedIn();
    renderRoute("/account/delete");

    expect(await screen.findByText(/everything Awrad keeps for it on the server are deleted/)).toBeInTheDocument();
    expect(screen.getByText(/signed out on every device and browser/)).toBeInTheDocument();
    expect(screen.getByText(/the app keeps working offline/)).toBeInTheDocument();
    expect(screen.getByText("There's no undo.")).toBeInTheDocument();
  });

  test("needs the password before it asks to confirm", async () => {
    signedIn();
    renderRoute("/account/delete");

    await userEvent.click(await screen.findByRole("button", { name: "Delete account" }));

    expect(await screen.findByText("Enter your current password.")).toBeInTheDocument();
    expect(screen.queryByRole("alertdialog")).toBeNull();
  });

  test("cancelling the confirmation deletes nothing", async () => {
    signedIn();
    const requests = recordRequests();
    renderRoute("/account/delete");

    const dialog = await askToDelete("a long passphrase");
    await userEvent.click(within(dialog).getByRole("button", { name: "Cancel" }));

    expect(screen.queryByRole("alertdialog")).toBeNull();
    expect(requests.some((request) => request.method === "POST")).toBe(false);
  });

  test("confirmed, the account is deleted and this browser shows signed out with a message", async () => {
    signedIn();
    server.use(specHandler("delete_account", 204));
    const requests = recordRequests();
    const { router } = renderRoute("/account/delete");

    const dialog = await askToDelete("a long passphrase");
    server.use(specProblem("get_current_account", "unauthenticated"));
    await userEvent.click(within(dialog).getByRole("button", { name: "Delete my account" }));

    expect(await screen.findByRole("status")).toHaveTextContent("Your account is deleted, and you're signed out.");
    expect(await screen.findByRole("link", { name: "Sign in" })).toBeInTheDocument();
    expect(router.options.context.queryClient.getQueryData(["account", "current"])).toBeNull();
    const remove = requests.find((request) => request.method === "POST");
    expect(remove?.path).toBe("/api/v1/account/delete");
    expect(remove?.body).toEqual({ current_password: "a long passphrase" });
  });

  test("a wrong password closes the dialog and shows on the field", async () => {
    signedIn();
    server.use(specProblem("delete_account", "validation_failed"));
    renderRoute("/account/delete");

    const dialog = await askToDelete("not my password");
    await userEvent.click(within(dialog).getByRole("button", { name: "Delete my account" }));

    expect(await screen.findByLabelText("Current password")).toHaveAccessibleDescription(
      "That isn't your current password.",
    );
    expect(screen.queryByRole("alertdialog")).toBeNull();
  });
});
