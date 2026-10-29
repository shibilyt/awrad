/** What the web learns from a picked recording before uploading it: its SHA-256 and its length. */

/** The file's SHA-256 as 64 lowercase hex digits (WebCrypto). */
export async function sha256Hex(file: Blob): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", await file.arrayBuffer());
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

/** How long to wait for the browser to read a file's length before going without. */
const MEASURE_TIMEOUT_MS = 5000;

/**
 * The recording's length in whole milliseconds, read by the browser from the file's metadata, or
 * `null` when it can't tell (the document's `duration_ms` is then `null`; the server never
 * decodes audio). Never rejects.
 */
export function measureDurationMs(file: Blob): Promise<number | null> {
  if (typeof URL.createObjectURL !== "function") return Promise.resolve(null);
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const element = new Audio();
    const done = (value: number | null) => {
      clearTimeout(timer);
      element.removeAttribute("src");
      URL.revokeObjectURL(url);
      resolve(value);
    };
    const timer = setTimeout(() => {
      done(null);
    }, MEASURE_TIMEOUT_MS);
    element.preload = "metadata";
    element.addEventListener("loadedmetadata", () => {
      const ms = Math.round(element.duration * 1000);
      done(Number.isFinite(ms) && ms >= 1 ? ms : null);
    });
    element.addEventListener("error", () => {
      done(null);
    });
    element.src = url;
  });
}
