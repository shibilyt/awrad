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
  test("the Library shows the built-ins and offers sign-in instead of New dhikr; no Your dhikrs tile", async () => {
    server.use(specProblem("get_current_account", "unauthenticated"));
    renderRoute("/library");

    expect(await screen.findByRole("link", { name: "Sign in" })).toHaveAttribute("href", "/sign-in");
    expect(screen.getByText(/Sign in to write your own dhikrs/)).toBeInTheDocument();
    expect(screen.queryByRole("link", { name: /^Your dhikrs/ })).not.toBeInTheDocument();
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
  test("a collection tile first in the tile row, with how many, next to New dhikr and Manage tags", async () => {
    server.use(...signedInWithEntities());
    renderRoute("/library");

    const tile = await screen.findByRole("link", { name: "Your dhikrs 2 dhikrs" });
    expect(tile).toHaveAttribute("href", "/library/yours");
    const tiles = within(screen.getByRole("list", { name: "Collections" })).getAllByRole("link");
    expect(tiles[0]).toBe(tile);
    // The Library section is gone: the tile's page lists them.
    expect(screen.queryByRole("list", { name: "Your dhikrs" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "New dhikr" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Manage tags" })).toHaveAttribute("href", "/library/tags");
  });

  test("the tile opens a list page like a collection's: newest first, each a link to its page", async () => {
    server.use(...signedInWithEntities());
    const { router } = renderRoute("/library");

    await userEvent.click(await screen.findByRole("link", { name: "Your dhikrs 2 dhikrs" }));
    expect(await screen.findByRole("heading", { level: 1, name: "Your dhikrs" })).toBeInTheDocument();
    expect(router.state.location.pathname).toBe("/library/yours");
    expect(screen.getByText("2 dhikrs")).toBeInTheDocument();
    const list = screen.getByRole("list", { name: "Your dhikrs" });
    // A Malayalam-only title shows in English too (any language, when the UI's and English are missing).
    expect(rowTitles(list)).toEqual(["Morning words", "ഹസ്ബിയല്ലാഹ്"]);
    expect(within(list).getAllByRole("link")[0]).toHaveAttribute("href", `/library/dhikrs/${MORNING_DHIKR_ID}`);
    expect(screen.getByRole("button", { name: "Back" })).toBeInTheDocument();
  });

  test("in Arabic the tile's count uses Arabic plurals", async () => {
    await i18next.changeLanguage("ar");
    server.use(...signedInWithEntities());
    renderRoute("/library");
    expect(await screen.findByRole("link", { name: `${i18next.t("library.yours.title")} ذكران` })).toBeInTheDocument();
  });

  test("an account with none has no tile; its list page offers New dhikr", async () => {
    server.use(...signedInWithEntities(() => []));
    const { unmount } = renderRoute("/library");
    expect(await screen.findByRole("button", { name: "New dhikr" })).toBeInTheDocument();
    expect(screen.queryByRole("link", { name: /^Your dhikrs/ })).not.toBeInTheDocument();
    unmount();

    renderRoute("/library/yours");
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

    const chips = await screen.findByRole("toolbar", { name: "Filter by tag" });
    expect(
      within(chips)
        .getAllByRole("button", { pressed: false })
        .map((chip) => chip.textContent),
    ).toEqual(["Evening", "Morning"]);

    await userEvent.click(within(chips).getByRole("button", { name: "Morning" }));
    expect(await screen.findByText("2 dhikrs have every chosen tag")).toBeInTheDocument();
    expect(within(chips).getByRole("button", { name: "Morning", pressed: true })).toBeInTheDocument();
    expect(rowTitles(screen.getByRole("list", { name: "Tagged dhikrs" }))).toEqual(["Morning words", "Tahleel"]);
    expect(router.state.location.search).toEqual({ tags: [MORNING_TAG_ID] });

    await userEvent.click(within(chips).getByRole("button", { name: "Evening" }));
    expect(await screen.findByText("1 dhikr has every chosen tag")).toBeInTheDocument();
    expect(rowTitles(screen.getByRole("list", { name: "Tagged dhikrs" }))).toEqual(["Tahleel"]);

    await userEvent.click(within(chips).getByRole("button", { name: "Morning" }));
    await userEvent.click(within(chips).getByRole("button", { name: "Evening" }));
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
