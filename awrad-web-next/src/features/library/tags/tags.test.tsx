import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, test } from "vitest";
import { recordRequests, renderRoute, type RecordedRequest } from "@/test/render";
import { server } from "@/test/setup";
import {
  EVENING_TAG_ID,
  MORNING_TAG_ID,
  TAHLEEL_ID,
  applied,
  changesHandler,
  exampleReceipt,
  signedInWithEntities,
} from "@/test/sync";

interface Command {
  entity_type: string;
  entity_id: string;
  op: string;
  base_version: number;
  document?: unknown;
}

async function sentCommands(requests: RecordedRequest[], count: number): Promise<Command[]> {
  const posts = () =>
    requests.filter((request) => request.method === "POST" && request.path === "/api/v1/sync/commands");
  await waitFor(() => {
    expect(posts()).toHaveLength(count);
    expect(posts().every((post) => post.body !== undefined)).toBe(true);
  });
  return posts().flatMap((post) => (post.body as { commands: Command[] }).commands);
}

describe("Manage tags", () => {
  test("lists the tags with how many dhikrs have each", async () => {
    server.use(...signedInWithEntities());
    renderRoute("/library/tags");

    const list = await screen.findByRole("list", { name: "Your tags" });
    const rows = within(list).getAllByRole("listitem");
    expect(rows.map((row) => row.querySelector("span")?.textContent)).toEqual(["Evening", "Morning"]);
    expect(rows[1]).toHaveTextContent("2 dhikrs");
  });

  test("a new tag is sent with its display and normalized names", async () => {
    const requests = recordRequests();
    server.use(...signedInWithEntities(), applied(1));
    renderRoute("/library/tags");

    await userEvent.type(await screen.findByRole("textbox", { name: "New tag" }), "  Before   SLEEP ");
    await userEvent.click(screen.getByRole("button", { name: "Add tag" }));

    const [command] = await sentCommands(requests, 1);
    expect(command).toMatchObject({
      entity_type: "user_tag",
      op: "put",
      base_version: 0,
      document: { name: "Before SLEEP", normalized_name: "before sleep" },
    });
    await waitFor(() => {
      expect(screen.getByRole("textbox", { name: "New tag" })).toHaveValue("");
    });
  });

  test("a name the account already has, or a blank one, is caught before sending", async () => {
    const requests = recordRequests();
    server.use(...signedInWithEntities());
    renderRoute("/library/tags");

    await userEvent.type(await screen.findByRole("textbox", { name: "New tag" }), "MORNING");
    await userEvent.click(screen.getByRole("button", { name: "Add tag" }));
    expect(await screen.findByText("You already have a tag called “Morning”.")).toBeInTheDocument();

    await userEvent.clear(screen.getByRole("textbox", { name: "New tag" }));
    await userEvent.type(screen.getByRole("textbox", { name: "New tag" }), "   ");
    await userEvent.click(screen.getByRole("button", { name: "Add tag" }));
    expect(await screen.findByText("Enter a name.")).toBeInTheDocument();
    expect(requests.some((request) => request.method === "POST")).toBe(false);
  });

  test("rename sends the new name on the tag's version", async () => {
    const requests = recordRequests();
    server.use(...signedInWithEntities(), applied(2));
    renderRoute("/library/tags");

    await userEvent.click(await screen.findByRole("button", { name: "Rename Morning" }));
    const sheet = await screen.findByRole("dialog", { name: "Rename tag" });
    const name = within(sheet).getByRole("textbox", { name: "Name" });
    await userEvent.clear(name);
    await userEvent.type(name, "Mornings");
    await userEvent.click(within(sheet).getByRole("button", { name: "Save" }));

    const [command] = await sentCommands(requests, 1);
    expect(command).toMatchObject({
      entity_id: MORNING_TAG_ID,
      op: "put",
      base_version: 1,
      document: { name: "Mornings", normalized_name: "mornings" },
    });
  });

  test("delete asks first, then removes the tag from the list", async () => {
    const requests = recordRequests();
    server.use(...signedInWithEntities(), applied(2));
    renderRoute("/library/tags");

    await userEvent.click(await screen.findByRole("button", { name: "Delete Evening" }));
    const dialog = await screen.findByRole("alertdialog", { name: "Delete “Evening”?" });
    await userEvent.click(within(dialog).getByRole("button", { name: "Delete" }));

    const [command] = await sentCommands(requests, 1);
    expect(command).toMatchObject({ entity_id: EVENING_TAG_ID, op: "delete", base_version: 1 });
  });
});

describe("Manage tags on a dhikr", () => {
  test("choosing tags sends the dhikr's personal record on its version", async () => {
    const requests = recordRequests();
    server.use(...signedInWithEntities(), applied(2));
    renderRoute("/library/dhikrs/tahleel");

    await userEvent.click(await screen.findByRole("button", { name: "Manage tags" }));
    const sheet = await screen.findByRole("dialog", { name: "Tags on this dhikr" });
    await userEvent.click(within(sheet).getByRole("checkbox", { name: "Evening" }));
    await userEvent.click(within(sheet).getByRole("button", { name: "Save" }));

    const [command] = await sentCommands(requests, 1);
    expect(command).toEqual(
      expect.objectContaining({
        entity_type: "dhikr_personal",
        entity_id: TAHLEEL_ID,
        op: "put",
        base_version: 1,
        document: { tag_ids: [MORNING_TAG_ID] },
      }),
    );
    await waitFor(() => {
      expect(screen.queryByRole("dialog", { name: "Tags on this dhikr" })).not.toBeInTheDocument();
    });
  });

  test("a new tag that merges into an existing one is chosen under the surviving ID", async () => {
    const requests = recordRequests();
    // The spec's merged receipt: the new tag joined 0192f0a0-…-0001 (Morning). Then the dhikr's tags.
    // The page first reads an account without Morning; after the merge, the feed has it.
    server.use(...signedInWithEntities((changes) => changes.filter(({ entity_id }) => entity_id === MORNING_TAG_ID)));
    server.use(
      changesHandler(() => [], true),
      applied(1),
    );
    server.use(exampleReceipt(1));
    renderRoute("/library/dhikrs/tahleel");

    await userEvent.click(await screen.findByRole("button", { name: "Manage tags" }));
    const sheet = await screen.findByRole("dialog", { name: "Tags on this dhikr" });
    await userEvent.type(within(sheet).getByRole("textbox", { name: "New tag" }), "MORNING");
    await userEvent.click(within(sheet).getByRole("button", { name: "Add tag" }));
    await waitFor(() => {
      expect(within(sheet).getByRole("checkbox", { name: "Morning" })).toBeChecked();
    });
    await userEvent.click(within(sheet).getByRole("button", { name: "Save" }));

    const [, personal] = await sentCommands(requests, 2);
    expect(personal?.document).toEqual({ tag_ids: [MORNING_TAG_ID] });
  });
});
