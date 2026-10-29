import { AUDIO_CONTENT_TYPES, AUDIO_MAX_BYTES, type UploadedAudio } from "@/shared/sync";

/**
 * The upload rules (contracts/audio/v1/fixtures/audio_upload_validity.json, README "Limits"):
 * the web checks a file with them before it asks to upload, and the server enforces them.
 */

export type AudioContentType = UploadedAudio["content_type"];
export type UploadRuleError = "unsupported_audio_type" | "invalid_size" | "file_too_large" | "storage_full";

export { AUDIO_MAX_BYTES };
/** Bytes one account may hold, ready and pending uploads together (500 MB, decimal). */
export const ACCOUNT_LIMIT_BYTES = 500_000_000;

function isAudioContentType(value: string): value is AudioContentType {
  return (AUDIO_CONTENT_TYPES as readonly string[]).includes(value);
}

/**
 * Whether an upload is allowed, or the first rule it breaks, in the contract's order: the type
 * (exactly `audio/mpeg` or `audio/mp4`), then the size (1 to 10,000,000 bytes), then the quota
 * (`used_bytes + byte_size` at most 500,000,000; exactly full is allowed).
 */
export function uploadRuleError(upload: {
  byte_size: number;
  content_type: string;
  used_bytes: number;
}): UploadRuleError | null {
  if (!isAudioContentType(upload.content_type)) return "unsupported_audio_type";
  if (upload.byte_size < 1) return "invalid_size";
  if (upload.byte_size > AUDIO_MAX_BYTES) return "file_too_large";
  if (upload.used_bytes + upload.byte_size > ACCOUNT_LIMIT_BYTES) return "storage_full";
  return null;
}

/** By extension: an `.mp3` is MP3, an `.m4a` is M4A/AAC (README "Media types on import"). */
const BY_EXTENSION: Readonly<Record<string, AudioContentType>> = { mp3: "audio/mpeg", m4a: "audio/mp4" };
/** System types for the same two, including the common `audio/x-m4a` for an `.m4a`. */
const BY_SYSTEM_TYPE: Readonly<Record<string, AudioContentType>> = {
  "audio/mpeg": "audio/mpeg",
  "audio/mp4": "audio/mp4",
  "audio/x-m4a": "audio/mp4",
};

/**
 * The media type to upload a picked file as (audio README, "Phones": Importing): only an `.mp3`
 * (`audio/mpeg`) or an `.m4a` (`audio/mp4`, however the system reports it, `audio/x-m4a`
 * included). `null`, refused as `unsupported_audio_type`, for anything else: a file named with
 * another extension (a raw `.aac` stream among them), even when the system calls it `audio/mp4`,
 * or one with no extension and no system type of the two.
 */
export function contentTypeOf(file: { name: string; type: string }): AudioContentType | null {
  const extension = /\.([^./\\]+)$/.exec(file.name)?.[1]?.toLowerCase();
  if (extension === undefined) return BY_SYSTEM_TYPE[file.type] ?? null;
  return BY_EXTENSION[extension] ?? null;
}
