import { afterEach, describe, expect, test, vi } from "vitest";
import { StorageError, putToStorage } from "./storage";

/** A stand-in XMLHttpRequest that records exactly what the request was given, and answers as told. */
class FakeRequest extends EventTarget {
  static last: FakeRequest | null = null;
  method = "";
  url = "";
  withCredentials = true;
  headers: [string, string][] = [];
  body: unknown = undefined;
  status = 0;
  readonly upload = new EventTarget();

  constructor() {
    super();
    FakeRequest.last = this;
  }

  open(method: string, url: string): void {
    this.method = method;
    this.url = url;
  }

  setRequestHeader(name: string, value: string): void {
    this.headers.push([name, value]);
  }

  send(body: unknown): void {
    this.body = body;
  }

  /** Storage's answer: progress, then the status. */
  answer(status: number): void {
    const progress = new ProgressEvent("progress", { lengthComputable: true, loaded: 2, total: 4 });
    this.upload.dispatchEvent(progress);
    this.status = status;
    this.dispatchEvent(new Event("load"));
  }
}

function lastRequest(): FakeRequest {
  if (FakeRequest.last === null) throw new Error("no request was made");
  return FakeRequest.last;
}

describe("putToStorage", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    FakeRequest.last = null;
  });

  test("PUTs the file to the link with exactly the given headers, no credentials, and reports progress", async () => {
    vi.stubGlobal("XMLHttpRequest", FakeRequest);
    const file = new Blob(["abcd"]);
    const headers = { "content-type": "audio/mp4", "x-amz-checksum-sha256": "c29tZQ==", "x-amz-meta-new": "kept" };
    const progress: number[] = [];

    const done = putToStorage("https://storage.example/upload?sig=1", headers, file, (fraction) => {
      progress.push(fraction);
    });
    lastRequest().answer(200);
    await done;

    const request = lastRequest();
    expect(request.method).toBe("PUT");
    expect(request.url).toBe("https://storage.example/upload?sig=1");
    expect(request.withCredentials).toBe(false);
    expect(request.headers).toEqual(Object.entries(headers));
    expect(request.body).toBe(file);
    expect(progress).toEqual([0.5, 1]);
  });

  test("a refusal or a lost request rejects with the status (0 for no answer)", async () => {
    vi.stubGlobal("XMLHttpRequest", FakeRequest);
    const refused = putToStorage("https://storage.example/upload", {}, new Blob(["x"]));
    lastRequest().answer(403);
    await expect(refused).rejects.toEqual(new StorageError(403));

    const lost = putToStorage("https://storage.example/upload", {}, new Blob(["x"]));
    lastRequest().dispatchEvent(new Event("error"));
    await expect(lost).rejects.toMatchObject({ status: 0 });
  });
});
