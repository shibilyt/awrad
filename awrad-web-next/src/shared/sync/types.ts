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
/** An uploaded recording, as a custom dhikr names it (sync.schema.json `uploaded_audio`). */
export type UploadedAudio = Schemas["UploadedAudio"];
/** A recording that stays on the phone that imported it (slice 3b). */
export interface LocalAudio {
  local_only: true;
}

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
  /**
   * `null`, a recording kept on the phone that added it (`{local_only: true}`), or one uploaded to
   * the account's private storage (slice 3c, contracts/audio/v1), which the web can add and play.
   */
  audio: null | LocalAudio | UploadedAudio;
  references: readonly Reference[];
}

export type UserTagDocument = Schemas["UserTagDocument"];
export type DhikrPersonalDocument = Schemas["DhikrPersonalDocument"];
/** The account practice policy (slice 3d, contracts/practice-settings/v1): one per account, its ID the account's. */
export type PracticePolicyDocument = Schemas["PracticePolicyDocument"];
/** A goal (slice 4, contracts/goal-model/v1 `goal_document`); its rules are in src/shared/goals. */
export type GoalDocument = Schemas["GoalDocument"];
/** The account's order of My Goals (slice 4): one per account, its ID the account's. */
export type GoalOrderDocument = Schemas["GoalOrderDocument"];

export interface DocumentOf {
  custom_dhikr: CustomDhikrDocument;
  user_tag: UserTagDocument;
  dhikr_personal: DhikrPersonalDocument;
  practice_policy: PracticePolicyDocument;
  goal: GoalDocument;
  goal_order: GoalOrderDocument;
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
  /** At most one, keyed by the account's ID; none until someone chooses practice settings. */
  readonly practice_policy: Readonly<Record<string, Entity<PracticePolicyDocument>>>;
  /** Goals (slice 4): kept from the feed; the goals feature arrives in slice 4b. */
  readonly goal: Readonly<Record<string, Entity<GoalDocument>>>;
  /** At most one, keyed by the account's ID. */
  readonly goal_order: Readonly<Record<string, Entity<GoalOrderDocument>>>;
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
