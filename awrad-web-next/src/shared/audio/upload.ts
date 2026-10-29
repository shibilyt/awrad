import { ApiProblem } from "@/shared/api/problem";
import { StorageError, putToStorage } from "@/shared/api/storage";
import { newUuidV7 } from "@/shared/identity";
import type { UploadedAudio } from "@/shared/sync";
import { completeAudioUpload, createAudioUpload, getAudioUsage, type UploadRequest } from "./api";
import { measureDurationMs, sha256Hex } from "./file";
import { contentTypeOf, uploadRuleError, type UploadRuleError } from "./rules";

/**
 * Uploading a recording from the web (contracts/audio/v1/README.md "Uploading"): check it against
 * the rules, reserve the upload, PUT the bytes straight to storage, confirm. The result is what a
 * custom dhikr's `audio` names; the caller then sends the dhikr's put through the change queue.
 */

/** Why a recording didn't upload, in terms the editor explains. */
export type UploadFailure =
  | { code: Exclude<UploadRuleError, "storage_full"> }
  | { code: "storage_full"; usedBytes: number; limitBytes: number }
  /** Storage holds different bytes than declared; the server deleted them. A retry starts over. */
  | { code: "upload_mismatch" }
  /** The bytes didn't reach storage (network, an expired link), even after one more try. */
  | { code: "upload_failed"; assetId: string };

export class AudioUploadError extends Error {
  readonly failure: UploadFailure;

  constructor(failure: UploadFailure) {
    super(failure.code);
    this.name = "AudioUploadError";
    this.failure = failure;
  }
}

export interface UploadOptions {
  /** The fraction of the bytes sent so far, 0 to 1. */
  onProgress?: (fraction: number) => void;
  /** An earlier attempt's `asset_id` for the same file, to try again without reserving twice. */
  assetId?: string;
}

function refused(code: UploadRuleError, usedBytes: number, limitBytes: number): AudioUploadError {
  return new AudioUploadError(code === "storage_full" ? { code, usedBytes, limitBytes } : { code });
}

function numberOr(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

/** The server's refusals of the rules, as failures; any other problem is rethrown as it is. */
function failureOf(error: unknown, usedBytes: number): AudioUploadError | null {
  if (!(error instanceof ApiProblem)) return null;
  switch (error.code) {
    case "unsupported_audio_type":
    case "invalid_size":
    case "file_too_large":
      return new AudioUploadError({ code: error.code });
    case "storage_full":
      return new AudioUploadError({
        code: "storage_full",
        usedBytes: numberOr(error.extensions["used_bytes"], usedBytes),
        limitBytes: numberOr(error.extensions["limit_bytes"], 0),
      });
    case "upload_mismatch":
      return new AudioUploadError({ code: "upload_mismatch" });
    default:
      return null;
  }
}

type Attempt = { status: "ready"; byteSize: number; contentType: UploadedAudio["content_type"] } | { status: "retry" };

/**
 * One reservation, PUT and confirmation. Reserving the same body again is idempotent: a fresh link
 * while pending, or the asset once it's ready (then there's nothing to send). A PUT storage
 * refused or that never arrived, and a confirmation that finds no object, are worth one retry.
 */
async function attempt(
  accountId: string,
  request: UploadRequest,
  file: Blob,
  options: UploadOptions,
): Promise<Attempt> {
  const reserved = await createAudioUpload(accountId, request);
  if ("asset" in reserved) {
    return { status: "ready", byteSize: reserved.asset.byte_size, contentType: reserved.asset.content_type };
  }
  try {
    await putToStorage(reserved.upload.upload_url, reserved.upload.upload_headers, file, options.onProgress);
    const asset = await completeAudioUpload(accountId, request.asset_id);
    return { status: "ready", byteSize: asset.byte_size, contentType: asset.content_type };
  } catch (error) {
    if (error instanceof StorageError) return { status: "retry" };
    if (error instanceof ApiProblem && error.code === "upload_incomplete") return { status: "retry" };
    throw error;
  }
}

/**
 * Uploads `file` for the signed-in `accountId` and resolves to the document's `audio`. Rejects
 * with an `AudioUploadError` for the reasons the editor explains, or with the `ApiProblem` (a
 * session or rate problem) or network error that stopped it.
 */
export async function uploadAudio(accountId: string, file: File, options: UploadOptions = {}): Promise<UploadedAudio> {
  const contentType = contentTypeOf(file);
  const upload = { byte_size: file.size, content_type: contentType };
  // The type and size need no network; a file that is too large is refused before the quota is
  // looked at, so nobody is told to free space that wouldn't help.
  const local = uploadRuleError({ ...upload, used_bytes: 0 });
  if (local !== null) throw refused(local, 0, 0);
  const usage = await getAudioUsage(accountId);
  const quota = uploadRuleError({ ...upload, used_bytes: usage.used_bytes });
  if (quota !== null) throw refused(quota, usage.used_bytes, usage.limit_bytes);

  const [sha256, durationMs] = await Promise.all([sha256Hex(file), measureDurationMs(file)]);
  const request: UploadRequest = { asset_id: options.assetId ?? newUuidV7(), ...upload, sha256 };
  try {
    for (let tries = 0; tries < 2; tries += 1) {
      const result = await attempt(accountId, request, file, options);
      if (result.status === "ready") {
        // Copied from the asset, as the server compares them (audio_mismatch otherwise).
        return {
          asset_id: request.asset_id,
          byte_size: result.byteSize,
          content_type: result.contentType,
          duration_ms: durationMs,
        };
      }
    }
  } catch (error) {
    throw failureOf(error, usage.used_bytes) ?? error;
  }
  throw new AudioUploadError({ code: "upload_failed", assetId: request.asset_id });
}
