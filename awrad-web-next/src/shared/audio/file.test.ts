import { afterEach, describe, expect, test, vi } from "vitest";
import { measureDurationMs, sha256Hex } from "./file";

describe("sha256Hex", () => {
  test("is the file's SHA-256 in 64 lowercase hex digits", async () => {
    expect(await sha256Hex(new Blob(["hello"]))).toBe(
      "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
    );
    expect(await sha256Hex(new Blob([]))).toBe("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
  });
});

/** An audio element whose metadata "loads" once given a source: the length `next` says, or an error. */
class FakeAudio extends EventTarget {
  static next: number | "error" = 0;
  preload = "";
  duration = Number.NaN;

  removeAttribute(): void {
    // Nothing to let go of.
  }

  set src(_url: string) {
    const outcome = FakeAudio.next;
    queueMicrotask(() => {
      if (outcome === "error") {
        this.dispatchEvent(new Event("error"));
        return;
      }
      this.duration = outcome;
      this.dispatchEvent(new Event("loadedmetadata"));
    });
  }
}

describe("measureDurationMs", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    // jsdom has none (src/test/setup.ts); take back the one these tests put in.
    Object.defineProperty(URL, "createObjectURL", { value: undefined, configurable: true, writable: true });
  });

  /** Object URLs, and audio elements that report `length` (seconds) once their metadata loads. */
  function withMedia(length: number | "error"): { revoked: string[] } {
    const revoked: string[] = [];
    Object.defineProperty(URL, "createObjectURL", {
      value: () => "blob:recording",
      configurable: true,
      writable: true,
    });
    vi.spyOn(URL, "revokeObjectURL").mockImplementation((url) => revoked.push(url));
    FakeAudio.next = length;
    vi.stubGlobal("Audio", FakeAudio);
    return { revoked };
  }

  test("reads the length from the file's metadata, in whole milliseconds, and frees the object URL", async () => {
    const { revoked } = withMedia(31.2504);
    expect(await measureDurationMs(new Blob(["x"]))).toBe(31250);
    expect(revoked).toEqual(["blob:recording"]);
  });

  test("is null when the browser can't read the file, or its length isn't a positive number", async () => {
    withMedia("error");
    expect(await measureDurationMs(new Blob(["x"]))).toBeNull();
    withMedia(Infinity);
    expect(await measureDurationMs(new Blob(["x"]))).toBeNull();
  });

  test("is null without object URLs", async () => {
    expect(await measureDurationMs(new Blob(["x"]))).toBeNull();
  });
});
