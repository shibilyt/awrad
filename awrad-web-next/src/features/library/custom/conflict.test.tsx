import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, test } from "vitest";
import { recordRequests, renderRoute, type RecordedRequest } from "@/test/render";
import { server } from "@/test/setup";
import { HASBI_ID, MORNING_DHIKR_ID, applied, exampleReceipt, signedInWithEntities } from "@/test/sync";

/** The spec's conflict receipt: the server has version 3, "Subhanallah". */
const conflict = () => exampleReceipt(3);

function commands(requests: RecordedRequest[]) {
  return requests
    .filter((request) => request.method === "POST" && request.path === "/api/v1/sync/commands")
    .flatMap((post) => (post.body as { commands: { base_version: number; op: string }[] } | undefined)?.commands ?? []);
}

async function editTitle(): Promise<void> {
  const title = (await screen.findAllByRole("textbox", { name: "English" }))[0];
  if (title === undefined) throw new Error("no title field");
  await userEvent.clear(title);
  await userEvent.type(title, "Mine");
  await userEvent.click(screen.getByRole("button", { name: "Save" }));
}

describe("conflict: changed on another device", () => {
  test("shows the server's version; Keep mine sends the edit again on the server's version", async () => {
    const requests = recordRequests();
    // The last handlers added answer first: the conflict, then the applied resend.
    server.use(...signedInWithEntities(), applied(4));
    server.use(conflict());
    const { router } = renderRoute(`/library/dhikrs/${MORNING_DHIKR_ID}/edit`);

    await editTitle();
    const dialog = await screen.findByRole("alertdialog", { name: "Changed on another device" });
    expect(within(dialog).getByText("This was changed on another device after you opened it.")).toBeInTheDocument();
    expect(within(dialog).getByText("Subhanallah")).toBeInTheDocument();
    expect(within(dialog).getByText("سُبْحَانَ ٱللَّهِ")).toBeInTheDocument();
    // components.md "Conflict banner": secondaryContainer, not the error roles; Keep mine, then Use theirs.
    expect(dialog.closest(".rounded-card")).toHaveClass("bg-secondary-container", "text-on-secondary-container");
    expect(
      within(dialog)
        .getAllByRole("button")
        .map((button) => button.textContent),
    ).toEqual(["Keep mine", "Use theirs"]);

    await userEvent.click(within(dialog).getByRole("button", { name: "Keep mine" }));

    await waitFor(() => {
      expect(commands(requests).map((command) => command.base_version)).toEqual([1, 3]);
    });
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/library/dhikrs/${MORNING_DHIKR_ID}`);
    });
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
  });

  test("Use theirs keeps the server's copy and sends nothing more", async () => {
    const requests = recordRequests();
    server.use(...signedInWithEntities(), conflict());
    const { router } = renderRoute(`/library/dhikrs/${MORNING_DHIKR_ID}/edit`);

    await editTitle();
    const dialog = await screen.findByRole("alertdialog", { name: "Changed on another device" });
    await userEvent.click(within(dialog).getByRole("button", { name: "Use theirs" }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/library/dhikrs/${MORNING_DHIKR_ID}`);
    });
    expect(commands(requests)).toHaveLength(1);
  });

  test("the dialog can't be dismissed without choosing", async () => {
    server.use(...signedInWithEntities(), conflict());
    renderRoute(`/library/dhikrs/${MORNING_DHIKR_ID}/edit`);

    await editTitle();
    await screen.findByRole("alertdialog", { name: "Changed on another device" });
    await userEvent.keyboard("{Escape}");
    expect(screen.getByRole("alertdialog", { name: "Changed on another device" })).toBeInTheDocument();
  });
});

describe("a custom dhikr's page", () => {
  test("its text, Edit, its tags with Manage tags, its references under Sources and Delete", async () => {
    server.use(...signedInWithEntities());
    renderRoute(`/library/dhikrs/${MORNING_DHIKR_ID}`);

    expect(await screen.findByRole("heading", { level: 1, name: "Morning words" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Edit" })).toHaveAttribute(
      "href",
      `/library/dhikrs/${MORNING_DHIKR_ID}/edit`,
    );
    expect(
      screen.getByText("Its recording is on the phone that added it. Audio is added from the phone app."),
    ).toBeInTheDocument();
    expect(within(screen.getByRole("list", { name: "Your tags" })).getByText("Morning")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Manage tags" })).toBeInTheDocument();
    const sources = screen.getByRole("region", { name: "Sources" });
    expect(within(sources).getByText("Sahih Muslim 2723")).toHaveClass("text-caption", "text-on-surface-variant");
    expect(screen.queryByRole("heading", { name: "Translation" })).toBeInTheDocument();
  });

  test("a title in Malayalam only, with no transliteration: no empty sections", async () => {
    server.use(...signedInWithEntities());
    renderRoute(`/library/dhikrs/${HASBI_ID}`);

    expect(await screen.findByRole("heading", { level: 1, name: "ഹസ്ബിയല്ലാഹ്" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Transliteration" })).not.toBeInTheDocument();
    expect(screen.getByText("Allah is sufficient for me; there is no god but Him.")).toBeInTheDocument();
  });

  test("Delete asks first, then sends one delete on the version shown and goes to the Library", async () => {
    const requests = recordRequests();
    server.use(...signedInWithEntities(), applied(2));
    const { router } = renderRoute(`/library/dhikrs/${MORNING_DHIKR_ID}`);

    await userEvent.click(await screen.findByRole("button", { name: "Delete dhikr" }));
    const dialog = await screen.findByRole("alertdialog", { name: "Delete “Morning words”?" });
    expect(commands(requests)).toHaveLength(0);
    await userEvent.click(within(dialog).getByRole("button", { name: "Delete" }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe("/library");
    });
    expect(commands(requests)).toEqual([expect.objectContaining({ op: "delete", base_version: 1 })]);
  });

  test("built-ins have no Edit or Delete, but can be tagged", async () => {
    server.use(...signedInWithEntities());
    renderRoute("/library/dhikrs/tahleel");

    expect(await screen.findByRole("button", { name: "Manage tags" })).toBeInTheDocument();
    expect(within(screen.getByRole("list", { name: "Your tags" })).getAllByRole("listitem")).toHaveLength(2);
    expect(screen.queryByRole("link", { name: "Edit" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Delete dhikr" })).not.toBeInTheDocument();
  });
});
