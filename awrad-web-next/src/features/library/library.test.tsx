import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import i18next from "i18next";
import { beforeEach, describe, expect, test, vi } from "vitest";
import { renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specProblem } from "@/test/spec";

beforeEach(() => {
  // Home asks who's signed in; the Library never calls the API.
  server.use(specProblem("get_current_account", "unauthenticated"));
});

/** The names of the dhikr rows in a list, in order. */
function rowTitles(list: HTMLElement): string[] {
  return within(list)
    .getAllByRole("link")
    .map((link) => link.querySelector("span > span")?.textContent ?? "");
}

describe("navigation", () => {
  test("home shows the featured collection tiles, each a link to its collection, and View all", async () => {
    renderRoute("/");

    const tiles = await screen.findByRole("list", { name: "Featured dhikr collections" });
    const tile = within(tiles).getByRole("link", { name: "Daily Essentials 4 dhikrs" });
    expect(tile).toHaveAttribute("href", "/library/collections/daily-essentials");
    expect(within(tiles).getByRole("link", { name: "Asma-ul Husna 100 dhikrs" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "View all" })).toHaveAttribute("href", "/library");
  });

  test("the bottom bar's Home and Library are links, Library selected on the Library", async () => {
    renderRoute("/library");

    const bar = await screen.findByRole("tablist", { name: "Main navigation" });
    const library = within(bar).getByRole("tab", { name: "Library" });
    expect(library).toHaveAttribute("href", "/library");
    expect(library).toHaveAttribute("aria-selected", "true");
    expect(within(bar).getByRole("tab", { name: "Home" })).toHaveAttribute("href", "/");
  });

  test("pushed pages (a collection, a dhikr) have Back and no bottom bar", async () => {
    const { unmount } = renderRoute("/library/collections/swalaths");
    expect(await screen.findByRole("heading", { level: 1, name: "Swalaths" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Back" })).toBeInTheDocument();
    expect(screen.queryByRole("tablist")).not.toBeInTheDocument();
    unmount();

    renderRoute("/library/dhikrs/tahleel");
    expect(await screen.findByRole("heading", { level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Back" })).toBeInTheDocument();
    expect(screen.queryByRole("tablist")).not.toBeInTheDocument();
  });

  test("a tile opens its collection, and a row opens the dhikr", async () => {
    const { router } = renderRoute("/");

    await userEvent.click(await screen.findByRole("link", { name: "Swalaths 6 dhikrs" }));
    expect(await screen.findByRole("heading", { level: 1, name: "Swalaths" })).toBeInTheDocument();
    expect(rowTitles(screen.getByRole("list", { name: "Swalaths" }))).toHaveLength(6);

    await userEvent.click(screen.getByRole("link", { name: /^Swalath al Nariyya/ }));
    expect(await screen.findByRole("heading", { level: 1, name: "Swalath al Nariyya" })).toBeInTheDocument();
    expect(router.state.location.pathname).toBe("/library/dhikrs/swalath-al-nariyya");
  });
});

describe("library and search", () => {
  test("lists the collections and every dhikr", async () => {
    renderRoute("/library");

    expect(await screen.findByRole("heading", { level: 1, name: "Library" })).toBeInTheDocument();
    expect(within(screen.getByRole("list", { name: "Collections" })).getAllByRole("link")).toHaveLength(5);
    expect(rowTitles(screen.getByRole("list", { name: "All dhikrs" }))).toHaveLength(113);
  });

  test("typing searches, keeps the query in the URL, and shows only the results", async () => {
    const { router } = renderRoute("/library");

    await userEvent.type(await screen.findByRole("searchbox", { name: "Search dhikrs" }), "astaghfirullah");

    expect(await screen.findByRole("status")).toHaveTextContent("1 dhikr found");
    expect(rowTitles(screen.getByRole("list", { name: "Search results" }))).toEqual(["Isthighfar"]);
    expect(screen.queryByRole("list", { name: "Collections" })).not.toBeInTheDocument();
    await vi.waitFor(() => {
      expect(router.state.location.search).toEqual({ q: "astaghfirullah" });
    });
  });

  test("a search in the URL is shown on load, ranked; nothing found shows the empty state", async () => {
    renderRoute("/library?q=rahman");

    expect(await screen.findByRole("searchbox")).toHaveValue("rahman");
    expect(rowTitles(screen.getByRole("list", { name: "Search results" }))).toEqual(["Ya Rahman", "Surah Ikhlas"]);

    await userEvent.clear(screen.getByRole("searchbox"));
    await userEvent.type(screen.getByRole("searchbox"), "xyzzy");
    expect(await screen.findByRole("status")).toHaveTextContent("No dhikrs match “xyzzy”");
    expect(screen.queryByRole("list", { name: "Search results" })).not.toBeInTheDocument();
  });

  test("clearing the search shows the library again and drops the query from the URL", async () => {
    const { router } = renderRoute("/library?q=swalath");

    await userEvent.click(await screen.findByRole("button", { name: "Clear search" }));

    expect(await screen.findByRole("list", { name: "All dhikrs" })).toBeInTheDocument();
    await vi.waitFor(() => {
      expect(router.state.location.search).toEqual({});
    });
  });

  test("Arabic counts use the Arabic plural forms", async () => {
    await i18next.changeLanguage("ar");
    renderRoute("/library");

    const tiles = await screen.findByRole("list", { name: "المجموعات" });
    expect(within(tiles).getByRole("link", { name: "أساسيات يومية 4 أذكار" })).toBeInTheDocument();
    expect(within(tiles).getByRole("link", { name: "الأسماء الحسنى 100 ذكر" })).toBeInTheDocument();
    expect(within(tiles).getByRole("link", { name: "الصلاة على النبي ﷺ 6 أذكار" })).toBeInTheDocument();
  });
});

describe("collection and not found", () => {
  test("Asma-ul Husna lists the 100 names in order", async () => {
    renderRoute("/library/collections/asma-ul-husna");

    expect(await screen.findByText("100 dhikrs")).toBeInTheDocument();
    const names = rowTitles(screen.getByRole("list", { name: "Asma-ul Husna" }));
    expect(names).toHaveLength(100);
    expect(names.slice(0, 3)).toEqual(["Ya Allah", "Ya Rahman", "Ya Raheem"]);
  });

  test("an unknown collection or dhikr shows not found", async () => {
    renderRoute("/library/collections/no-such-collection");
    expect(await screen.findByRole("heading", { name: "Not in the library" })).toBeInTheDocument();
    expect(screen.getByText(/This collection isn't in the library/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Go to the library" })).toHaveAttribute("href", "/library");
  });

  test("an unknown dhikr shows not found", async () => {
    renderRoute("/library/dhikrs/no-such-dhikr");
    expect(await screen.findByText(/This dhikr isn't in the library/)).toBeInTheDocument();
  });
});
