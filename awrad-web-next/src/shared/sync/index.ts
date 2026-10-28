// The change queue on the web (contracts/sync/v1, ADR-2026-10-28): the account's custom dhikrs,
// tags and personal records, read from the changes feed and edited one command at a time. Online
// only: no queue, no local copy beyond the query cache.
export { fetchSyncState, sendEdit, PAGE_SIZE } from "./api";
export {
  customDhikrProblems,
  isValidReference,
  textProblems,
  codePointLength,
  DHIKR_KINDS,
  LONG_TEXT_MAX,
  REFERENCES_MAX,
  TITLE_MAX,
  type FieldCode,
  type FieldProblem,
} from "./customDhikrValidity";
export { syncQuery, useSendEdit, useSessionProblem, useSyncState } from "./query";
export { EMPTY_STATE, applyChanges, applyReceipt, knownVersion } from "./state";
export { caseFold, normalizeTagName, tagDisplayName, type TagName, type TagNameProblem } from "./tagName";
export type * from "./types";
