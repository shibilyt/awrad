import { HttpResponse, http } from "msw";
import { expect, test } from "vitest";
import { ApiProblem } from "@/shared/api/problem";
import { setCsrfToken } from "@/shared/api/client";
import { recordRequests } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";
import { UPLOAD_HEADERS, storageHandlers, type StoragePut } from "@/test/storage";
import { ACCOUNT_ID } from "@/test/sync";
import { AudioUploadError, uploadAudio, type UploadFailure } from "./upload";

/** SHA-256 of "hello", the test file's bytes. */
const HELLO_SHA256 = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824";

function mp3(name = "dhikr.mp3", bytes: BlobPart[] = ["hello"], type = "audio/mpeg"): File {
  return new File(bytes, name, { type });
}

/** Storage accepting (or refusing, with `status`) PUTs to the example's link, recording each. */
function storage(status = 200): StoragePut[] {
  const puts: StoragePut[] = [];
  server.use(...storageHandlers(status, puts));
  return puts;
}

function happyPath(): void {
  server.use(
    specHandler("get_browser_csrf_token", 200),
    specHandler("get_audio_usage", 200),
    specHandler("create_audio_upload", 201),
    specHandler("complete_audio_upload", 200),
  );
}

async function failureOf(promise: Promise<unknown>): Promise<UploadFailure> {
  const error: unknown = await promise.then(
    () => null,
    (reason: unknown) => reason,
  );
  if (!(error instanceof AudioUploadError)) throw new Error(`expected an AudioUploadError, got ${String(error)}`);
  return error.failure;
}

test("reserves, PUTs the file with exactly the upload headers, confirms, and returns the document's audio", async () => {
  happyPath();
  const puts = storage();
  const requests = recordRequests();
  const progress: number[] = [];

  const audio = await uploadAudio(ACCOUNT_ID, mp3(), { onProgress: (fraction) => progress.push(fraction) });

  // The asset's size and type (from complete_audio_upload's example), and no duration in jsdom.
  expect(audio).toEqual({
    asset_id: expect.stringMatching(/^[0-9a-f]{8}-[0-9a-f]{4}-7/) as string,
    byte_size: 4182733,
    content_type: "audio/mpeg",
    duration_ms: null,
  });
  const api = requests.filter((request) => request.path.startsWith("/api/v1/audio"));
  expect(api.map((request) => `${request.method} ${request.path}`)).toEqual([
    "GET /api/v1/audio_assets/usage",
    "POST /api/v1/audio_uploads",
    `POST /api/v1/audio_uploads/${audio.asset_id}/complete`,
  ]);
  for (const request of api) expect(request.headers.get("X-Awrad-Account")).toBe(ACCOUNT_ID);
  expect(api[1]?.body).toEqual({
    asset_id: audio.asset_id,
    byte_size: 5,
    content_type: "audio/mpeg",
    sha256: HELLO_SHA256,
  });
  expect(puts).toHaveLength(1);
  expect(puts[0]?.body).toBe("hello");
  // Every upload header exactly as given, and none of the API's own (storage.test.ts checks the
  // request sets nothing else; the browser adds its own, such as Origin and Content-Length).
  expect(puts[0]?.headers).toMatchObject(UPLOAD_HEADERS);
  for (const header of ["x-csrf-token", "x-awrad-account", "idempotency-key", "cookie"]) {
    expect(puts[0]?.headers).not.toHaveProperty(header);
  }
  expect(progress.at(-1)).toBe(1);
});

test("an .m4a is uploaded as audio/mp4, whatever its system type", async () => {
  happyPath();
  storage();
  const requests = recordRequests();
  await uploadAudio(ACCOUNT_ID, mp3("recording.M4A", ["hello"], "audio/x-m4a"));
  const reserve = requests.find((request) => request.path === "/api/v1/audio_uploads");
  expect(reserve?.body).toMatchObject({ content_type: "audio/mp4" });
});

test("a ready asset on reserving (a repeat) skips the PUT and the confirmation", async () => {
  // The 200 "ready" example (the spec gives the 200 two examples, so specHandler can't pick one).
  const ready = {
    asset: {
      asset_id: "0192f0e0-0000-7000-8000-000000000001",
      byte_size: 4182733,
      content_type: "audio/mpeg",
      status: "ready",
      created_at: "2026-10-29T08:01:12Z",
    },
  };
  server.use(
    specHandler("get_browser_csrf_token", 200),
    specHandler("get_audio_usage", 200),
    http.post(new URL("/api/v1/audio_uploads", window.location.origin).href, () => HttpResponse.json(ready)),
  );
  const puts = storage();
  const requests = recordRequests();
  const audio = await uploadAudio(ACCOUNT_ID, mp3());
  expect(audio.byte_size).toBe(4182733);
  expect(puts).toHaveLength(0);
  expect(requests.some((request) => request.path.endsWith("/complete"))).toBe(false);
});

test("refuses an unsupported type, an empty file and one too large before asking the server", async () => {
  const requests = recordRequests();
  expect(await failureOf(uploadAudio(ACCOUNT_ID, mp3("song.wav", ["hello"], "audio/wav")))).toEqual({
    code: "unsupported_audio_type",
  });
  // A raw AAC stream isn't an .m4a, even when the system calls it audio/mp4.
  for (const type of ["audio/aac", "audio/mp4"]) {
    expect(await failureOf(uploadAudio(ACCOUNT_ID, mp3("dhikr.aac", ["hello"], type)))).toEqual({
      code: "unsupported_audio_type",
    });
  }
  expect(await failureOf(uploadAudio(ACCOUNT_ID, mp3("empty.mp3", [])))).toEqual({ code: "invalid_size" });
  const big = new Uint8Array(10_000_001);
  expect(await failureOf(uploadAudio(ACCOUNT_ID, mp3("big.mp3", [big])))).toEqual({ code: "file_too_large" });
  expect(requests).toHaveLength(0);
});

test("refuses a file that would fill the account's storage, with the usage, before reserving", async () => {
  server.use(
    specHandler("get_browser_csrf_token", 200),
    specHandler("get_audio_usage", 200, { from: () => ({ used_bytes: 499_999_998, limit_bytes: 500_000_000 }) }),
  );
  const requests = recordRequests();
  expect(await failureOf(uploadAudio(ACCOUNT_ID, mp3()))).toEqual({
    code: "storage_full",
    usedBytes: 499_999_998,
    limitBytes: 500_000_000,
  });
  expect(requests.map((request) => request.path)).toEqual(["/api/v1/audio_assets/usage"]);
});

test.each([
  ["file_too_large", { code: "file_too_large" }],
  ["unsupported_audio_type", { code: "unsupported_audio_type" }],
  ["storage_full", { code: "storage_full", usedBytes: 497300000, limitBytes: 500000000 }],
] as const)("the server's %s refusal becomes the same failure", async (code, failure) => {
  server.use(
    specHandler("get_browser_csrf_token", 200),
    specHandler("get_audio_usage", 200),
    specProblem("create_audio_upload", code),
  );
  expect(await failureOf(uploadAudio(ACCOUNT_ID, mp3()))).toEqual(failure);
});

test("a mismatch on confirming is upload_mismatch (the server deleted the object)", async () => {
  server.use(
    specHandler("get_browser_csrf_token", 200),
    specHandler("get_audio_usage", 200),
    specHandler("create_audio_upload", 201),
    specProblem("complete_audio_upload", "upload_mismatch"),
  );
  storage();
  expect(await failureOf(uploadAudio(ACCOUNT_ID, mp3()))).toEqual({ code: "upload_mismatch" });
});

test("a PUT storage refuses is tried once more on a fresh link, then given up with the asset_id to retry", async () => {
  happyPath();
  const puts = storage(403);
  const requests = recordRequests();
  const failure = await failureOf(uploadAudio(ACCOUNT_ID, mp3()));
  expect(failure.code).toBe("upload_failed");
  expect(puts).toHaveLength(2);
  const reserves = requests.filter((request) => request.path === "/api/v1/audio_uploads");
  expect(reserves).toHaveLength(2);
  // The same body both times: the server answers a repeat with a fresh link.
  expect(reserves[1]?.body).toEqual(reserves[0]?.body);
  if (failure.code !== "upload_failed") throw new Error("unreachable");
  expect(failure.assetId).toBe((reserves[0]?.body as { asset_id: string }).asset_id);

  // Trying again with that asset_id reserves the same upload, not a second one.
  server.resetHandlers();
  happyPath();
  storage();
  const again = await uploadAudio(ACCOUNT_ID, mp3(), { assetId: failure.assetId });
  expect(again.asset_id).toBe(failure.assetId);
});

test("upload_incomplete on confirming PUTs again and confirms again", async () => {
  server.use(
    specHandler("get_browser_csrf_token", 200),
    specHandler("get_audio_usage", 200),
    specHandler("create_audio_upload", 201),
    specProblem("complete_audio_upload", "upload_incomplete", { once: true }),
    specHandler("complete_audio_upload", 200),
  );
  const puts = storage();
  await uploadAudio(ACCOUNT_ID, mp3());
  expect(puts).toHaveLength(2);
});

test("a session problem is rethrown as the ApiProblem", async () => {
  setCsrfToken("token");
  server.use(specProblem("get_audio_usage", "account_mismatch"));
  await expect(uploadAudio(ACCOUNT_ID, mp3())).rejects.toBeInstanceOf(ApiProblem);
});
