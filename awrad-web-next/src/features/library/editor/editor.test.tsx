import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, test } from "vitest";
import type { Receipt } from "@/shared/sync";
import { recordRequests, type RecordedRequest } from "@/test/render";
import { renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import {
  MORNING_DHIKR,
  MORNING_DHIKR_ID,
  MORNING_TAG_ID,
  applied,
  receiptHandler,
  signedInWithEntities,
} from "@/test/sync";

const UUID_V7 = /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

interface Command {
  command_id: string;
  entity_type: string;
  entity_id: string;
  op: string;
  base_version: number;
  document?: Record<string, unknown>;
}

/** The commands the page sent, in order, once their bodies have been read. */
async function sentCommands(requests: RecordedRequest[], count: number): Promise<Command[]> {
  const posts = () =>
    requests.filter((request) => request.method === "POST" && request.path === "/api/v1/sync/commands");
  await waitFor(() => {
    expect(posts()).toHaveLength(count);
    expect(posts().every((post) => post.body !== undefined)).toBe(true);
  });
  return posts().flatMap((post) => (post.body as { commands: Command[] }).commands);
}

/** The first field labelled `name` (title fields come before transliteration and translation). */
function field(name: string, index = 0): HTMLElement {
  const found = screen.getAllByRole("textbox", { name })[index];
  if (found === undefined) throw new Error(`no field ${name}`);
  return found;
}

describe("validation (the shared custom_dhikr_validity rules)", () => {
  test("saving nothing asks for the Arabic and a title, and sends nothing", async () => {
    const requests = recordRequests();
    server.use(...signedInWithEntities());
    renderRoute("/library/dhikrs/new");

    await userEvent.click(await screen.findByRole("button", { name: "Save" }));

    expect(await screen.findByText("Check the highlighted fields.")).toBeInTheDocument();
    expect(field("Arabic text")).toHaveAccessibleDescription(expect.stringContaining("Enter the Arabic text."));
    expect(screen.getByText("Give it a title in at least one language.")).toBeInTheDocument();
    expect(requests.some((request) => request.method === "POST")).toBe(false);
  });

  test("a title over 120 characters and a reference outside the Qur'an are caught before sending", async () => {
    const requests = recordRequests();
    server.use(...signedInWithEntities());
    renderRoute("/library/dhikrs/new");

    await userEvent.type(await screen.findByRole("textbox", { name: "Arabic text" }), "سبحان الله");
    await userEvent.click(field("English"));
    await userEvent.paste("a".repeat(121));
    await userEvent.click(screen.getByRole("button", { name: "Add reference" }));
    await userEvent.click(await screen.findByRole("button", { name: "Qur'an" }));
    await userEvent.type(screen.getByRole("textbox", { name: "Surah" }), "115");
    await userEvent.type(screen.getByRole("textbox", { name: "First ayah" }), "1");
    await userEvent.type(screen.getByRole("textbox", { name: "Last ayah" }), "1");
    await userEvent.click(screen.getByRole("button", { name: "Save" }));

    expect(await screen.findByText("Use at most 120 characters.")).toBeInTheDocument();
    expect(screen.getByText(/Fill in what this reference needs/)).toBeInTheDocument();
    expect(requests.some((request) => request.method === "POST")).toBe(false);
  });
});

describe("saving", () => {
  test("a new dhikr is one put on version 0, then its tags; then its page", async () => {
    const requests = recordRequests();
    server.use(...signedInWithEntities(), applied(1));
    server.use(applied(1));
    const { router } = renderRoute("/library/dhikrs/new");

    await userEvent.click(await screen.findByRole("radio", { name: "Du'a" }));
    await userEvent.type(screen.getByRole("textbox", { name: "Arabic text" }), "حسبي الله");
    await userEvent.type(field("Malayalam"), "ഹസ്ബിയല്ലാഹ്");
    await userEvent.click(screen.getByRole("button", { name: "Add reference" }));
    await userEvent.click(await screen.findByRole("button", { name: "Qur'an" }));
    await userEvent.type(screen.getByRole("textbox", { name: "Surah" }), "9");
    await userEvent.type(screen.getByRole("textbox", { name: "First ayah" }), "129");
    await userEvent.type(screen.getByRole("textbox", { name: "Last ayah" }), "129");
    await userEvent.click(
      within(screen.getByRole("group", { name: "Tags" })).getByRole("checkbox", { name: "Morning" }),
    );
    await userEvent.click(screen.getByRole("button", { name: "Save" }));

    const [dhikr, personal] = await sentCommands(requests, 2);
    expect(dhikr).toMatchObject({ entity_type: "custom_dhikr", op: "put", base_version: 0 });
    expect(dhikr?.entity_id).toMatch(UUID_V7);
    expect(dhikr?.document).toEqual({
      kind: "dua",
      arabic: "حسبي الله",
      title: { en: null, ar: null, ml: "ഹസ്ബിയല്ലാഹ്" },
      transliteration: { en: null, ml: null },
      translation: { en: null, ar: null, ml: null },
      audio: null,
      references: [{ id: "ref-1", type: "quran", surah: 9, ayah_start: 129, ayah_end: 129 }],
    });
    expect(personal).toMatchObject({
      entity_type: "dhikr_personal",
      entity_id: dhikr?.entity_id,
      op: "put",
      base_version: 0,
      document: { tag_ids: [MORNING_TAG_ID] },
    });
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/library/dhikrs/${dhikr?.entity_id ?? ""}`);
    });
  });

  test("editing keeps the phone's recording marker and sends nothing for unchanged tags", async () => {
    const requests = recordRequests();
    server.use(...signedInWithEntities(), applied(2));
    renderRoute(`/library/dhikrs/${MORNING_DHIKR_ID}/edit`);

    expect(
      await screen.findByText("Its recording is on the phone that added it. Audio is added from the phone app."),
    ).toBeInTheDocument();
    await userEvent.clear(field("English"));
    await userEvent.type(field("English"), "Morning remembrance");
    await userEvent.click(screen.getByRole("button", { name: "Save" }));

    const [command] = await sentCommands(requests, 1);
    expect(command).toMatchObject({ entity_id: MORNING_DHIKR_ID, base_version: 1 });
    expect(command?.document).toEqual({ ...MORNING_DHIKR, title: { en: "Morning remembrance", ar: null, ml: null } });
  });

  test("a rejected save shows why", async () => {
    server.use(
      ...signedInWithEntities(),
      receiptHandler((receipts) => ({
        ...(receipts[5] as Receipt & { status: "rejected" }),
        code: "custom_dhikr_limit_reached",
        fields: [],
      })),
    );
    renderRoute("/library/dhikrs/new");

    await userEvent.type(await screen.findByRole("textbox", { name: "Arabic text" }), "سبحان الله");
    await userEvent.type(field("English"), "Subhanallah");
    await userEvent.click(screen.getByRole("button", { name: "Save" }));

    expect(
      await screen.findByText("You have 1,000 dhikrs of your own, the most an account can have."),
    ).toBeInTheDocument();
  });
});
