import type { components } from "@/shared/api/schema.gen";
import type { DhikrKind, Reference } from "@/shared/dhikr-catalog";
import type { FieldCode } from "./customDhikrValidity";

/**
 * The change queue's wire shapes (contracts/sync/v1/sync.schema.json) as the web uses them, and
 * the account's entities as the web holds them: the whole account, read from the changes feed.
 */
type Schemas = components["schemas"];

export type EntityType = Schemas["SyncEntityType"];
export type Receipt = Schemas["SyncReceipt"];
export type Outcome = Schemas["SyncOutcome"];
export type Change = Schemas["SyncChange"];
export type CascadedChange = Schemas["SyncCascadedChange"];
export type Current = Schemas["SyncCurrent"];
export type RejectionCode = Schemas["SyncRejectedReceipt"]["code"];

/** Text in each language, or `null` where the user gave none (API STYLE §3). */
export interface Languages3 {
  en: string | null;
  ar: string | null;
  ml: string | null;
}

/** A user's own dhikr (`custom_dhikr_document`); the catalog's reference shape. */
export interface CustomDhikrDocument {
  kind: DhikrKind;
  arabic: string;
  title: Languages3;
  transliteration: { en: string | null; ml: string | null };
  translation: Languages3;
  /** A recording kept on the phone that added it; the web never has audio (uploads are slice 3c). */
  audio: null | { local_only: true };
  references: readonly Reference[];
}

export type UserTagDocument = Schemas["UserTagDocument"];
export type DhikrPersonalDocument = Schemas["DhikrPersonalDocument"];

export interface DocumentOf {
  custom_dhikr: CustomDhikrDocument;
  user_tag: UserTagDocument;
  dhikr_personal: DhikrPersonalDocument;
}

/** An active entity: its ID, the version the server last told us, and its document. */
export interface Entity<D> {
  readonly id: string;
  readonly version: number;
  readonly document: D;
}

/** Every active entity of the account, by type and ID, and the revision it was read at. */
export interface SyncState {
  readonly custom_dhikr: Readonly<Record<string, Entity<CustomDhikrDocument>>>;
  readonly user_tag: Readonly<Record<string, Entity<UserTagDocument>>>;
  readonly dhikr_personal: Readonly<Record<string, Entity<DhikrPersonalDocument>>>;
  readonly headRevision: number;
}

/** One edit, before it gets its `command_id`: a whole new document, or a delete. */
export type Edit = {
  [T in EntityType]:
    | { entity_type: T; entity_id: string; op: "put"; base_version: number; document: DocumentOf[T] }
    | { entity_type: T; entity_id: string; op: "delete"; base_version: number };
}[EntityType];

/** A field problem in a rejected command, its pointer relative to the document (`/title/en`). */
export interface RejectedField {
  field: string;
  code: FieldCode;
}

/**
 * What became of an edit, once its receipt is applied to the cache. A `duplicate` is reported as
 * its original.
 */
export type EditResult =
  | { status: "applied"; version: number }
  /** `base_version` was stale: `current` is the server's copy, `edit` what the user wanted. */
  | { status: "conflict"; edit: Edit; current: Current }
  /** A tag create whose name another tag has: use `mergedInto` from now on. */
  | { status: "merged"; mergedInto: string }
  /** It's been deleted (or is a merged tag's old ID). */
  | { status: "gone" }
  | { status: "rejected"; code: RejectionCode; fields: RejectedField[] };
