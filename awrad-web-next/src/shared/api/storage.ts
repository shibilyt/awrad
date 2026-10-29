/**
 * Uploads straight to private storage (R2) with a signed link the API handed out
 * (`create_audio_upload`, contracts/audio/v1, root ADR-2026-10-29). The bytes never pass through
 * the API. The link and its headers are opaque: the file goes as it is, with every header in
 * `headers` exactly as given (R2 checks the signed `content-type` and `x-amz-checksum-sha256`),
 * and nothing else of ours: no cookie, no CSRF token, no `Accept-Language`.
 *
 * `XMLHttpRequest` rather than `fetch`, because it reports upload progress.
 */

/** Storage didn't take the file: `status` is its HTTP status, or 0 when the request never got an answer. */
export class StorageError extends Error {
  readonly status: number;

  constructor(status: number) {
    super(`storage answered ${String(status)}`);
    this.name = "StorageError";
    this.status = status;
  }
}

/** `PUT`s `body` to `url` with exactly `headers`; `onProgress` gets the fraction sent, 0 to 1. */
export function putToStorage(
  url: string,
  headers: Readonly<Record<string, string>>,
  body: Blob,
  onProgress: (fraction: number) => void = () => undefined,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const request = new XMLHttpRequest();
    request.open("PUT", url);
    // A cross-origin request without credentials: R2's CORS allows the web origin, not cookies.
    request.withCredentials = false;
    for (const [name, value] of Object.entries(headers)) request.setRequestHeader(name, value);
    request.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable && event.total > 0) onProgress(event.loaded / event.total);
    });
    request.addEventListener("load", () => {
      if (request.status >= 200 && request.status < 300) {
        onProgress(1);
        resolve();
      } else {
        reject(new StorageError(request.status));
      }
    });
    request.addEventListener("error", () => {
      reject(new StorageError(0));
    });
    request.addEventListener("abort", () => {
      reject(new StorageError(0));
    });
    request.send(body);
  });
}
