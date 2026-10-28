import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import i18next from "i18next";
import { describe, expect, test } from "vitest";
import { renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specProblem } from "@/test/spec";
import { MORNING_DHIKR_ID, MORNING_TAG_ID, signedInWithEntities } from "@/test/sync";

/** The titles of the dhikr rows in a list, in order. */
function rowTitles(list: HTMLElement): string[] {
  return within(list)
    .getAllByRole("link")
    .map((link) => link.querySelector("span > span")?.textContent ?? "");
}

describe("signed out", () => {
  test("the Library shows the built-ins, and Your dhikrs offers sign-in instead of New dhikr", async () => {
    server.use(specProblem("get_current_account", "unauthenticated"));
    renderRoute("/library");

    expect(await screen.findByRole("link", { name: "Sign in" })).toHaveAttribute("href", "/sign-in");
    expect(screen.getByRole("heading", { name: "Your dhikrs" })).toBeInTheDocument();
    expect(screen.getByText(/Sign in to write your own dhikrs/)).toBeInTheDocument();
    expect(screen.getByRole("list", { name: "All dhikrs" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "New dhikr" })).not.toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Filter by tag" })).not.toBeInTheDocument();
  });

  test("the editor and Manage tags ask to sign in", async () => {
    server.use(specProblem("get_current_account", "unauthenticated"));
    const { unmount } = renderRoute("/library/dhikrs/new");
    expect(await screen.findByRole("link", { name: "Sign in" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Save" })).not.toBeInTheDocument();
    unmount();

    renderRoute("/library/tags");
    expect(await screen.findByRole("link", { name: "Sign in" })).toBeInTheDocument();
  });
});

describe("Your dhikrs", () => {
  test("lists the account's dhikrs, newest first, each a link to its page, with New dhikr and Manage tags", async () => {
    server.use(...signedInWithEntities());
    renderRoute("/library");

    const list = await screen.findByRole("list", { name: "Your dhikrs" });
    // A Malayalam-only title shows in English too (any language, when the UI's and English are missing).
    expect(rowTitles(list)).toEqual(["Morning words", "ഹസ്ബിയല്ലാഹ്"]);
    expect(within(list).getAllByRole("link")[0]).toHaveAttribute("href", `/library/dhikrs/${MORNING_DHIKR_ID}`);
    expect(screen.getByRole("button", { name: "New dhikr" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Manage tags" })).toHaveAttribute("href", "/library/tags");
  });

  test("an account with none offers New dhikr", async () => {
    server.use(...signedInWithEntities(() => []));
    renderRoute("/library");

    expect(await screen.findByText("You haven't added a dhikr of your own yet.")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "New dhikr" })).toHaveAttribute("href", "/library/dhikrs/new");
  });

  test("New dhikr opens the editor", async () => {
    server.use(...signedInWithEntities());
    const { router } = renderRoute("/library");

    await userEvent.click(await screen.findByRole("button", { name: "New dhikr" }));
    expect(await screen.findByRole("heading", { level: 1, name: "New dhikr" })).toBeInTheDocument();
    expect(router.state.location.pathname).toBe("/library/dhikrs/new");
  });

  test("a feed that can't be read offers to try again", async () => {
    server.use(...signedInWithEntities().slice(0, 2), specProblem("list_sync_changes", "rate_limited"));
    renderRoute("/library");

    expect(await screen.findByText("Too many changes at once. Wait a little and try again.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Try again" })).toBeInTheDocument();
  });
});

describe("tag filter", () => {
  test("chips for the account's tags; choosing several shows the dhikrs with all of them (AND)", async () => {
    server.use(...signedInWithEntities());
    const { router } = renderRoute("/library");

    const chips = await screen.findByRole("grid", { name: "Filter by tag" });
    expect(
      within(chips)
        .getAllByRole("row")
        .map((row) => row.textContent),
    ).toEqual(["Evening", "Morning"]);

    await userEvent.click(within(chips).getByRole("row", { name: "Morning" }));
    expect(await screen.findByText("2 dhikrs have every chosen tag")).toBeInTheDocument();
    expect(rowTitles(screen.getByRole("list", { name: "Tagged dhikrs" }))).toEqual(["Morning words", "Tahleel"]);
    expect(router.state.location.search).toEqual({ tags: [MORNING_TAG_ID] });

    await userEvent.click(within(chips).getByRole("row", { name: "Evening" }));
    expect(await screen.findByText("1 dhikr has every chosen tag")).toBeInTheDocument();
    expect(rowTitles(screen.getByRole("list", { name: "Tagged dhikrs" }))).toEqual(["Tahleel"]);

    await userEvent.click(within(chips).getByRole("row", { name: "Morning" }));
    await userEvent.click(within(chips).getByRole("row", { name: "Evening" }));
    expect(screen.queryByRole("list", { name: "Tagged dhikrs" })).not.toBeInTheDocument();
    expect(router.state.location.search).toEqual({});
  });

  test("the filter is kept in the URL, and a tag no one has any more is ignored", async () => {
    server.use(...signedInWithEntities());
    renderRoute(
      `/library?tags=${encodeURIComponent(JSON.stringify([MORNING_TAG_ID, "0192f0a0-0000-7000-8000-00000000dead"]))}`,
    );

    expect(await screen.findByText("2 dhikrs have every chosen tag")).toBeInTheDocument();
  });

  test("in Arabic the counts use Arabic plurals", async () => {
    await i18next.changeLanguage("ar");
    server.use(...signedInWithEntities());
    renderRoute(`/library?tags=${encodeURIComponent(JSON.stringify([MORNING_TAG_ID]))}`);

    expect(await screen.findByText("ذكران يحملان كل الوسوم المختارة")).toBeInTheDocument();
    expect(document.documentElement).toHaveAttribute("dir", "rtl");
  });
});
