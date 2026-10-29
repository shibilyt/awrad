import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, test } from "vitest";
import type { Current, Receipt } from "@/shared/sync";
import { recordRequests, renderRoute, type RecordedRequest } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";
import { UPLOAD_HEADERS, storageHandlers, uploadHandlers, type StoragePut } from "@/test/storage";
import {
  MORNING_DHIKR_ID,
  UPLOADED_ASSET_ID,
  UPLOADED_DHIKR,
  UPLOADED_DHIKR_ID,
  applied,
  receiptHandler,
  signedInWithEntities,
  withUploadedDhikr,
} from "@/test/sync";

/**
 * "Add audio" in the custom dhikr editor (slice 3c): the shared upload rules, then reserve, PUT
 * with exactly the upload headers, confirm, and the dhikr's put naming the asset on Save.
 */

const UUID_V7 = /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

function file(name = "dhikr.mp3", bytes: BlobPart[] = ["hello"], type = "audio/mpeg"): File {
  return new File(bytes, name, { type });
}

/** The editor's file input (React Aria's FileTrigger keeps it hidden behind "Add audio"). */
function picker(): HTMLInputElement {
  const input = document.querySelector<HTMLInputElement>('input[type="file"]');
  if (input === null) throw new Error("no file input");
  return input;
}

async function pick(chosen: File): Promise<void> {
  // Like choosing "All files" in the system dialog: the accept list doesn't filter.
  await userEvent.setup({ applyAccept: false }).upload(picker(), chosen);
}

function storage(status = 200): StoragePut[] {
  const puts: StoragePut[] = [];
  server.use(...storageHandlers(status, puts));
  return puts;
}

async function openNewEditor(): Promise<void> {
  renderRoute("/library/dhikrs/new");
  await userEvent.type(await screen.findByRole("textbox", { name: "Arabic text" }), "سبحان الله");
  const [english] = screen.getAllByRole("textbox", { name: "English" });
  if (english === undefined) throw new Error("no English title");
  await userEvent.type(english, "Glory be to Allah");
}

function audioSection(): HTMLElement {
  return screen.getByRole("region", { name: "Audio" });
}

function paths(requests: RecordedRequest[]): string[] {
  return requests.map((request) => `${request.method} ${request.path}`);
}

async function sentDocument(requests: RecordedRequest[]): Promise<Record<string, unknown>> {
  const post = () => requests.find((request) => request.path === "/api/v1/sync/commands");
  await waitFor(() => {
    expect(post()?.body).toBeDefined();
  });
  const [command] = (post()?.body as { commands: { document: Record<string, unknown> }[] }).commands;
  if (command === undefined) throw new Error("no command");
  return command.document;
}

describe("adding audio", () => {
  test("uploads the file, shows it, and saving sends the dhikr naming the confirmed asset", async () => {
    server.use(...signedInWithEntities(), ...uploadHandlers(), applied(1));
    const puts = storage();
    const requests = recordRequests();
    await openNewEditor();
    expect(within(audioSection()).getByText("No recording yet.")).toBeInTheDocument();

    await pick(file());

    expect(await within(audioSection()).findByText("Recording, 4.2 MB")).toBeInTheDocument();
    expect(puts).toHaveLength(1);
    expect(puts[0]?.headers).toMatchObject(UPLOAD_HEADERS);
    expect(puts[0]?.headers).not.toHaveProperty("x-csrf-token");
    expect(puts[0]?.body).toBe("hello");
    const reserve = requests.find((request) => request.path === "/api/v1/audio_uploads");
    const assetId = (reserve?.body as { asset_id: string }).asset_id;
    expect(assetId).toMatch(UUID_V7);
    expect(reserve?.body).toMatchObject({ byte_size: 5, content_type: "audio/mpeg" });

    await userEvent.click(screen.getByRole("button", { name: "Save" }));
    const document = await sentDocument(requests);
    // Size and type as the confirmed asset has them (complete_audio_upload's example).
    expect(document["audio"]).toEqual({
      asset_id: assetId,
      byte_size: 4182733,
      content_type: "audio/mpeg",
      duration_ms: null,
    });
    // The upload is confirmed before the put is sent. (Reads, and the browser's CORS preflight, aside.)
    const order = paths(requests).filter((path) => !/^(GET|OPTIONS) /.test(path));
    expect(order).toEqual([
      "POST /api/v1/audio_uploads",
      expect.stringMatching(/^PUT \/awrad-private-dhikr\//) as string,
      `POST /api/v1/audio_uploads/${assetId}/complete`,
      "POST /api/v1/sync/commands",
    ]);
  });
});

describe("a recording that can't upload", () => {
  test("a file over 10 MB, and one that isn't MP3 or M4A, are refused before anything is sent", async () => {
    server.use(...signedInWithEntities());
    const requests = recordRequests();
    await openNewEditor();
    const before = requests.length;

    await pick(file("long.mp3", [new Uint8Array(10_000_001)]));
    expect(await within(audioSection()).findByRole("alert")).toHaveTextContent(
      "This file is larger than 10 MB. Choose a smaller recording.",
    );
    await pick(file("song.wav", ["hello"], "audio/wav"));
    expect(await within(audioSection()).findByRole("alert")).toHaveTextContent("Choose an MP3 or M4A file.");
    expect(within(audioSection()).queryByRole("button", { name: "Try again" })).not.toBeInTheDocument();
    // A raw AAC stream too (audio README, "Phones": Importing).
    await pick(file("long.mp3", [new Uint8Array(10_000_001)]));
    await within(audioSection()).findByText(/larger than 10 MB/);
    await pick(file("dhikr.aac", ["hello"], "audio/aac"));
    expect(await within(audioSection()).findByRole("alert")).toHaveTextContent("Choose an MP3 or M4A file.");
    expect(within(audioSection()).getByText("No recording yet.")).toBeInTheDocument();
    expect(requests).toHaveLength(before);
  });

  test("storage full says how much is used, from the server's refusal", async () => {
    server.use(
      ...signedInWithEntities(),
      specHandler("get_audio_usage", 200),
      specProblem("create_audio_upload", "storage_full"),
    );
    await openNewEditor();

    await pick(file());

    expect(await within(audioSection()).findByRole("alert")).toHaveTextContent(
      "Your audio storage is full (497.3 MB of 500 MB used). Remove recordings from other dhikrs to make room.",
    );
    expect(within(audioSection()).getByText("No recording yet.")).toBeInTheDocument();
  });

  test("a mismatch says so, and Try again uploads afresh under a new asset_id", async () => {
    server.use(
      ...signedInWithEntities(),
      specHandler("get_audio_usage", 200),
      specHandler("create_audio_upload", 201),
      specProblem("complete_audio_upload", "upload_mismatch", { once: true }),
      specHandler("complete_audio_upload", 200),
    );
    storage();
    const requests = recordRequests();
    await openNewEditor();

    await pick(file());
    expect(await within(audioSection()).findByRole("alert")).toHaveTextContent(
      "The recording didn't arrive intact. Try again.",
    );
    expect(screen.getByRole("button", { name: "Save" })).toBeEnabled();
    await userEvent.click(within(audioSection()).getByRole("button", { name: "Try again" }));

    expect(await within(audioSection()).findByText("Recording, 4.2 MB")).toBeInTheDocument();
    const reserves = requests.filter((request) => request.path === "/api/v1/audio_uploads");
    const ids = reserves.map((request) => (request.body as { asset_id: string }).asset_id);
    expect(ids).toHaveLength(2);
    expect(ids[1]).not.toBe(ids[0]);
  });

  test("an upload storage keeps refusing says so, and Try again reserves the same upload again", async () => {
    server.use(...signedInWithEntities(), ...uploadHandlers());
    storage(403);
    const requests = recordRequests();
    await openNewEditor();

    await pick(file());
    expect(await within(audioSection()).findByRole("alert")).toHaveTextContent(
      "Couldn't upload the recording. Check your connection and try again.",
    );
    server.use(...storageHandlers(200));
    await userEvent.click(within(audioSection()).getByRole("button", { name: "Try again" }));

    expect(await within(audioSection()).findByText("Recording, 4.2 MB")).toBeInTheDocument();
    const ids = requests
      .filter((request) => request.path === "/api/v1/audio_uploads")
      .map((request) => (request.body as { asset_id: string }).asset_id);
    expect(new Set(ids).size).toBe(1);
  });
});

describe("a dhikr's recording", () => {
  test("an uploaded one shows its size and length; Remove saves the dhikr without it", async () => {
    server.use(...signedInWithEntities(withUploadedDhikr), applied(4));
    const requests = recordRequests();
    renderRoute(`/library/dhikrs/${UPLOADED_DHIKR_ID}/edit`);

    expect(await screen.findByText("Recording, 4.2 MB, 0:31")).toBeInTheDocument();
    await userEvent.click(within(audioSection()).getByRole("button", { name: "Remove recording" }));
    expect(within(audioSection()).getByText("No recording yet.")).toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: "Save" }));

    expect(await sentDocument(requests)).toEqual({ ...UPLOADED_DHIKR, audio: null });
  });

  test("Replace uploads the new file and saving names it instead", async () => {
    server.use(...signedInWithEntities(withUploadedDhikr), ...uploadHandlers(), applied(4));
    storage();
    const requests = recordRequests();
    renderRoute(`/library/dhikrs/${UPLOADED_DHIKR_ID}/edit`);
    await screen.findByText("Recording, 4.2 MB, 0:31");
    expect(within(audioSection()).getByRole("button", { name: "Replace recording" })).toBeInTheDocument();

    await pick(file("new.m4a", ["hello"], "audio/x-m4a"));
    expect(await within(audioSection()).findByText("Recording, 4.2 MB")).toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: "Save" }));

    const reserve = requests.find((request) => request.path === "/api/v1/audio_uploads");
    expect(reserve?.body).toMatchObject({ content_type: "audio/mp4" });
    const audio = (await sentDocument(requests))["audio"] as { asset_id: string };
    expect(audio.asset_id).toBe((reserve?.body as { asset_id: string }).asset_id);
    expect(audio.asset_id).not.toBe(UPLOADED_ASSET_ID);
  });

  test("a phone's recording says it's on the phone, and can be replaced or removed", async () => {
    server.use(...signedInWithEntities());
    renderRoute(`/library/dhikrs/${MORNING_DHIKR_ID}/edit`);

    expect(
      await within(await screen.findByRole("region", { name: "Audio" })).findByText(
        "Audio is on the phone that added it.",
      ),
    ).toBeInTheDocument();
    expect(within(audioSection()).getByRole("button", { name: "Replace recording" })).toBeInTheDocument();
    expect(within(audioSection()).getByRole("button", { name: "Remove recording" })).toBeInTheDocument();
  });

  test("audio_not_found from the server explains itself, and shows on the recording", async () => {
    server.use(
      ...signedInWithEntities(withUploadedDhikr),
      receiptHandler((receipts) => ({
        ...(receipts[5] as Receipt & { status: "rejected" }),
        code: "audio_not_found",
        fields: [{ field: "/document/audio/asset_id", code: "not_found" }],
        current: { version: 3, state: "active", document: UPLOADED_DHIKR as Current["document"] },
      })),
    );
    renderRoute(`/library/dhikrs/${UPLOADED_DHIKR_ID}/edit`);
    await screen.findByText("Recording, 4.2 MB, 0:31");

    await userEvent.click(screen.getByRole("button", { name: "Save" }));

    const dialog = await screen.findByRole("alertdialog", { name: "Change refused" });
    expect(dialog).toHaveTextContent("This dhikr's recording is no longer in your storage.");
    await userEvent.click(within(dialog).getByRole("button", { name: "OK" }));
    expect(await within(audioSection()).findByRole("alert")).toHaveTextContent(
      "This recording is no longer in your storage. Add it again, or remove it, then save.",
    );
    await waitFor(() => {
      expect(within(audioSection()).getByRole("button", { name: "Replace recording" })).toHaveFocus();
    });
  });
});
