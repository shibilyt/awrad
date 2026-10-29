import { screen, within } from "@testing-library/react";
import i18next from "i18next";
import { describe, expect, test } from "vitest";
import { recordRequests, renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";

/** The account page's "Audio storage" (slice 3c), from `get_audio_usage`. */

const ACCOUNT_ID = "0b6f6a1e-6c1f-4b8e-9a51-2f3d7c1e8a90"; // get_current_account's example

/** The term and its value in the "Audio storage" card. */
async function audioStorage(): Promise<string> {
  const term = await screen.findByText(i18next.t("account.page.audioStorage"));
  const card = term.closest("dl");
  if (card === null) throw new Error("no audio storage card");
  return within(card).getByRole("definition").textContent;
}

describe("audio storage on the account page", () => {
  test("shows what the recordings use of the limit, in decimal megabytes, for the signed-in account", async () => {
    server.use(specHandler("get_current_account", 200), specHandler("get_audio_usage", 200));
    const requests = recordRequests();
    renderRoute("/account");

    // The usage example: 120,482,733 of 500,000,000 bytes.
    expect(await screen.findByText("120.5 MB of 500 MB")).toBeInTheDocument();
    expect(await audioStorage()).toBe("120.5 MB of 500 MB");
    const usage = requests.find((request) => request.path === "/api/v1/audio_assets/usage");
    expect(usage?.headers.get("X-Awrad-Account")).toBe(ACCOUNT_ID);
  });

  test("an empty account shows 0 MB; Arabic uses its own digits and unit", async () => {
    server.use(
      specHandler("get_current_account", 200),
      specHandler("get_audio_usage", 200, { from: () => ({ used_bytes: 0, limit_bytes: 500_000_000 }) }),
    );
    renderRoute("/account");
    expect(await screen.findByText("0 MB of 500 MB")).toBeInTheDocument();

    await i18next.changeLanguage("ar");
    const expected = i18next.t("account.page.audioStorageUsed", {
      used: new Intl.NumberFormat("ar", { style: "unit", unit: "megabyte" }).format(0),
      limit: new Intl.NumberFormat("ar", { style: "unit", unit: "megabyte" }).format(500),
    });
    expect(await screen.findByText(expected)).toBeInTheDocument();
  });

  test("a failed read says so, and the rest of the page still works", async () => {
    server.use(specHandler("get_current_account", 200), specProblem("get_audio_usage", "rate_limited"));
    renderRoute("/account");

    expect(await screen.findByText("Couldn't load your audio storage.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Sign out" })).toBeInTheDocument();
  });
});
