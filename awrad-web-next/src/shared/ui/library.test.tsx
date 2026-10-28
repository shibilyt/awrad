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
import { FilterChips } from "./TagChips";

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
    expect(showsBottomBar("/library/tags")).toBe(false);
    expect(showsBottomBar("/library/yours")).toBe(false);
  });
});

describe("FilterChips", () => {
  function Chips(): ReactElement {
    const [selected, setSelected] = useState<string[]>(["evening"]);
    return (
      <FilterChips
        label="Filter by tag"
        chips={[
          { id: "evening", label: "Evening" },
          { id: "morning", label: "Morning" },
        ]}
        selected={selected}
        onChange={setSelected}
      />
    );
  }

  test("toggle buttons named by their label with their state; on is primary with a check", async () => {
    render(<Chips />);

    expect(screen.getByRole("toolbar", { name: "Filter by tag" })).toBeInTheDocument();
    const evening = screen.getByRole("button", { name: "Evening", pressed: true });
    const morning = screen.getByRole("button", { name: "Morning", pressed: false });
    expect(evening).toHaveClass("min-h-touch-target");
    expect(evening.firstElementChild).toHaveClass("bg-primary", "text-on-primary", "rounded-chip", "px-md", "py-sm");
    expect(evening.querySelector("svg")).not.toBeNull();
    expect(morning.firstElementChild).toHaveClass("bg-secondary-container", "text-on-secondary-container");
    expect(morning.querySelector("svg")).toBeNull();

    await userEvent.click(morning);
    expect(screen.getByRole("button", { name: "Morning", pressed: true })).toBeInTheDocument();
    await userEvent.click(evening);
    expect(screen.getByRole("button", { name: "Evening", pressed: false })).toBeInTheDocument();
  });

  test("on a surface card an off chip fills with background", () => {
    render(
      <Card>
        <Chips />
      </Card>,
    );
    expect(screen.getByRole("button", { name: "Morning" }).firstElementChild).toHaveClass("bg-background");
  });
});
