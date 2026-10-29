import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import i18next from "i18next";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { DEFAULT_POLICY } from "@/shared/practice";
import { policyConflict, policyWith, resetClock, sentCommands, setClock, signedInWithPolicy } from "@/test/practice";
import { recordRequests, renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { ACCOUNT_ID, applied, exampleReceipt, signedInWithEntities } from "@/test/sync";

beforeEach(() => {
  setClock();
});
afterEach(() => {
  resetClock();
});

async function openPage(): Promise<void> {
  renderRoute("/account/practice");
  expect(await screen.findByRole("heading", { level: 1, name: "Practice settings" })).toBeInTheDocument();
  // The settings show once the changes feed is read.
  expect(await screen.findByRole("radiogroup", { name: "New day starts at" })).toBeInTheDocument();
}

const radio = (group: string, name: string) =>
  within(screen.getByRole("radiogroup", { name: group })).getByRole("radio", { name });

describe("practice settings", () => {
  test("the account page links to it", async () => {
    server.use(...signedInWithEntities());
    renderRoute("/account");
    expect(await screen.findByRole("link", { name: "Practice settings" })).toHaveAttribute("href", "/account/practice");
  });

  test("an account with no policy shows the defaults, and its first edit creates it on version 0", async () => {
    const requests = recordRequests();
    server.use(...signedInWithPolicy(null), applied(1));
    await openPage();

    expect(radio("New day starts at", "Midnight")).toBeChecked();
    expect(radio("Calculation method", "University of Islamic Sciences, Karachi")).toBeChecked();
    expect(radio("Madhab for Asr", "Standard (Shafi'i, Maliki, Hanbali)")).toBeChecked();
    expect(radio("Week starts on", "Monday")).toBeChecked();
    expect(screen.getByText("No corrections yet.")).toBeInTheDocument();

    await userEvent.click(radio("New day starts at", "Maghrib"));

    await waitFor(() => {
      expect(sentCommands(requests)).toEqual([
        {
          command_id: expect.any(String) as string,
          entity_type: "practice_policy",
          entity_id: ACCOUNT_ID,
          op: "put",
          base_version: 0,
          document: { ...DEFAULT_POLICY, day_reset: "maghrib" },
        },
      ]);
    });
  });

  test("the Maghrib reset with no location in this browser says the day starts at midnight here", async () => {
    server.use(...signedInWithPolicy(policyWith({ day_reset: "maghrib" }), 2));
    await openPage();

    expect(radio("New day starts at", "Maghrib")).toBeChecked();
    expect(
      screen.getByText(
        "This browser has no location yet, so here the day starts at midnight. Choose a location below.",
      ),
    ).toBeInTheDocument();
    // The Hijri date is the local date's, as with the midnight reset.
    expect(screen.getByText("18 Jumada al-Ula 1448")).toBeInTheDocument();
  });

  test("the account's policy is shown, and an edit goes on its version with the other settings kept", async () => {
    const requests = recordRequests();
    const policy = policyWith({ calculation_method: "dubai", madhab: "hanafi", week_start: "saturday" });
    server.use(...signedInWithPolicy(policy, 3), applied(4));
    await openPage();

    expect(radio("Calculation method", "Dubai")).toBeChecked();
    expect(radio("Madhab for Asr", "Hanafi")).toBeChecked();
    expect(radio("Week starts on", "Saturday")).toBeChecked();

    await userEvent.click(radio("Week starts on", "Sunday"));

    await waitFor(() => {
      expect(sentCommands(requests)).toMatchObject([
        { base_version: 3, document: { ...policy, week_start: "sunday" } },
      ]);
    });
  });
});

describe("conflicts, refusals and Arabic", () => {
  test("a conflict merges by setting with the loaded copy as the base and sends the merge, without asking", async () => {
    const requests = recordRequests();
    const theirs = policyWith({ week_start: "sunday" });
    // The last handlers added answer first: the conflict, then the merged put applied.
    server.use(...signedInWithPolicy(DEFAULT_POLICY, 3), applied(5));
    server.use(policyConflict(theirs, 4));
    await openPage();

    await userEvent.click(radio("New day starts at", "Maghrib"));

    await waitFor(() => {
      expect(sentCommands(requests)).toMatchObject([
        { base_version: 3, document: { ...DEFAULT_POLICY, day_reset: "maghrib" } },
        { base_version: 4, document: { ...theirs, day_reset: "maghrib" } },
      ]);
    });
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
  });

  test("merged corrections that aren't valid keep the other device's, with a notice, and nothing more is sent", async () => {
    const requests = recordRequests();
    const theirs = policyWith({ hijri_corrections: [{ year: 1448, month: 4, offset_days: 1 }] });
    server.use(...signedInWithPolicy(DEFAULT_POLICY, 1));
    server.use(policyConflict(theirs, 2));
    await openPage();

    await userEvent.click(screen.getByRole("button", { name: "Adjust this month" }));
    const sheet = await screen.findByRole("dialog", { name: "When did Jumada al-Ula 1448 start?" });
    await userEvent.click(within(sheet).getByRole("radio", { name: /^1 day earlier/ }));

    expect(
      await screen.findByText(
        "Your Hijri corrections clashed with ones made on another device, so that device's were kept.",
      ),
    ).toBeInTheDocument();
    expect(sentCommands(requests)).toHaveLength(1);
  });

  test("a refused change says so", async () => {
    server.use(...signedInWithPolicy(DEFAULT_POLICY, 1), exampleReceipt(5));
    await openPage();

    await userEvent.click(radio("Madhab for Asr", "Hanafi"));

    expect(
      await screen.findByText("Awrad didn't accept this change. Reload the page and try again."),
    ).toBeInTheDocument();
  });

  test("in Arabic the page is right to left", async () => {
    server.use(...signedInWithPolicy(DEFAULT_POLICY, 1));
    await i18next.changeLanguage("ar");
    renderRoute("/account/practice");

    expect(await screen.findByRole("heading", { level: 1, name: "إعدادات العبادة" })).toBeInTheDocument();
    expect(document.documentElement).toHaveAttribute("dir", "rtl");
    expect(
      await screen.findByText("18 جمادى الأولى 1448", {
        normalizer: (text) => text.replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x660)),
      }),
    ).toBeInTheDocument();
  });
});
