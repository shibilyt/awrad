import {
  RouterProvider,
  createMemoryHistory,
  createRootRoute,
  createRoute,
  createRouter,
} from "@tanstack/react-router";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState, type ReactElement } from "react";
import { describe, expect, test, vi } from "vitest";
import { mainTabOf, showsBottomBar } from "./AppShell";
import { Card } from "./Card";
import { CollectionTile } from "./CollectionTile";
import { SearchField } from "./SearchField";

/** Renders `ui` as the only page of a throwaway router, so router links work. */
async function renderInRouter(ui: () => ReactElement): Promise<void> {
  const root = createRootRoute();
  const page = createRoute({ getParentRoute: () => root, path: "/", component: ui });
  const router = createRouter({
    routeTree: root.addChildren([page]),
    history: createMemoryHistory({ initialEntries: ["/"] }),
  });
  render(<RouterProvider router={router} />);
  await router.load();
}

describe("CollectionTile", () => {
  test("is one link to the collection, named by its title and count, a collectionTile square on surface", async () => {
    await renderInRouter(() => (
      <CollectionTile to="/library/collections/$key" params={{ key: "ramadan" }} heading="Ramadan" count="3 dhikrs" />
    ));

    const tile = await screen.findByRole("link", { name: "Ramadan 3 dhikrs" });
    expect(tile).toHaveAttribute("href", "/library/collections/ramadan");
    expect(tile).toHaveClass("size-collection-tile", "rounded-tile", "bg-surface", "focus-ring");
    // The arrow is drawn, not a button inside the link.
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
  });

  test("fills with background on a surface card", async () => {
    await renderInRouter(() => (
      <Card>
        <CollectionTile to="/" heading="Dhikrs" count="3 dhikrs" />
      </Card>
    ));
    expect(await screen.findByRole("link", { name: "Dhikrs 3 dhikrs" })).toHaveClass("bg-background");
  });
});

describe("SearchField", () => {
  function Controlled({ onChange }: { onChange: (value: string) => void }): ReactElement {
    const [value, setValue] = useState("");
    return (
      <SearchField
        label="Search dhikrs"
        value={value}
        onChange={(next) => {
          setValue(next);
          onChange(next);
        }}
      />
    );
  }

  test("is a labelled searchbox; typing reports the text; Clear search empties it", async () => {
    const onChange = vi.fn();
    render(<Controlled onChange={onChange} />);

    const box = screen.getByRole("searchbox", { name: "Search dhikrs" });
    expect(box).toHaveAttribute("placeholder", "Search dhikrs");
    await userEvent.type(box, "ya");
    expect(onChange).toHaveBeenLastCalledWith("ya");

    await userEvent.click(screen.getByRole("button", { name: "Clear search" }));
    expect(box).toHaveValue("");
    expect(onChange).toHaveBeenLastCalledWith("");
  });

  test("Escape clears it too", async () => {
    const onChange = vi.fn();
    render(<Controlled onChange={onChange} />);

    await userEvent.type(screen.getByRole("searchbox"), "ya{Escape}");
    expect(screen.getByRole("searchbox")).toHaveValue("");
  });
});

describe("main tabs", () => {
  test("the Library and its pages are the Library tab; everything else is Home", () => {
    expect(mainTabOf("/library")).toBe("library");
    expect(mainTabOf("/library/dhikrs/tahleel")).toBe("library");
    expect(mainTabOf("/")).toBe("home");
    expect(mainTabOf("/account")).toBe("home");
    expect(mainTabOf("/library-old")).toBe("home");
  });

  test("the bottom bar shows on the tabs, not on pages pushed onto them", () => {
    expect(showsBottomBar("/")).toBe(true);
    expect(showsBottomBar("/library")).toBe(true);
    expect(showsBottomBar("/account")).toBe(true);
    expect(showsBottomBar("/library/collections/ramadan")).toBe(false);
    expect(showsBottomBar("/library/dhikrs/tahleel")).toBe(false);
  });
});
