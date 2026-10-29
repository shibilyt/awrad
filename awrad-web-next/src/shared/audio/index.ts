// A user's own recordings (slice 3c, contracts/audio/v1, root ADR-2026-10-29): the upload rules,
// uploading a file to private storage, signed links to play one, and the storage used. Shared by
// the Library (the editor and the player) and the account page (storage used).
export {
  completeAudioUpload,
  createAudioUpload,
  getAudioDownload,
  getAudioUsage,
  type AudioAsset,
  type AudioUpload,
  type AudioUsage,
  type SignedLink,
  type UploadRequest,
} from "./api";
export { measureDurationMs, sha256Hex } from "./file";
export {
  ACCOUNT_LIMIT_BYTES,
  AUDIO_MAX_BYTES,
  contentTypeOf,
  uploadRuleError,
  type AudioContentType,
  type UploadRuleError,
} from "./rules";
export { AudioUploadError, uploadAudio, type UploadFailure, type UploadOptions } from "./upload";
export { AUDIO_USAGE_KEY, audioUsageQuery, formatMegabytes } from "./usage";
