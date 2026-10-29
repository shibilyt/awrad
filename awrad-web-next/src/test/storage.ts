import { HttpResponse, http, type HttpHandler } from "msw";
import { specHandler } from "./spec";

/**
 * Private storage (R2) for upload tests: the signed link in `create_audio_upload`'s example, with
 * the CORS the bucket has (the web origin may PUT, GET and HEAD), since the browser checks it.
 */

/** `create_audio_upload`'s 201 example: where the file goes, and the headers to send with it. */
export const UPLOAD_URL =
  "https://example-account.r2.cloudflarestorage.com/awrad-private-dhikr/0192f0e0-0000-7000-8000-000000000001";
export const UPLOAD_HEADERS = {
  "content-type": "audio/mpeg",
  "x-amz-checksum-sha256": "eVllD5+mm2J5s2lOJQYFnLZwYswPfprSejRlKNNB5bw=",
};
const CORS = {
  "Access-Control-Allow-Origin": window.location.origin,
  "Access-Control-Allow-Methods": "PUT, GET, HEAD",
  "Access-Control-Allow-Headers": "content-type, x-amz-checksum-sha256",
};

export interface StoragePut {
  headers: Record<string, string>;
  body: string;
}

/** Storage answering PUTs to the example's link with `status`, recording each in `puts`. */
export function storageHandlers(status = 200, puts: StoragePut[] = []): HttpHandler[] {
  return [
    http.options(UPLOAD_URL, () => new HttpResponse(null, { status: 204, headers: CORS })),
    http.put(UPLOAD_URL, async ({ request }) => {
      puts.push({ headers: Object.fromEntries(request.headers.entries()), body: await request.text() });
      return new HttpResponse(null, { status, headers: CORS });
    }),
  ];
}

/** Signed in, with the usage example, a new upload (201) and its confirmation (200). */
export function uploadHandlers(): HttpHandler[] {
  return [
    specHandler("get_audio_usage", 200),
    specHandler("create_audio_upload", 201),
    specHandler("complete_audio_upload", 200),
  ];
}
