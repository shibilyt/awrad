import { useQuery } from "@tanstack/react-query";
import { useEffect } from "react";
import type { Dhikr } from "@/shared/dhikr-catalog";
import type { Language } from "@/shared/i18n";
import { currentAccountQuery } from "@/shared/session";
import {
  useSessionProblem,
  useSyncState,
  type CustomDhikrDocument,
  type Entity,
  type Languages3,
  type SyncState,
  type UserTagDocument,
} from "@/shared/sync";

/**
 * The signed-in account's own dhikrs and tags as the Library shows them. The web is online-only
 * and signed in for these (root ADR-2026-10-28): signed out, the Library shows the built-ins and
 * offers sign-in instead.
 */
export type Yours =
  | { status: "loading" }
  | { status: "signedOut" }
  | { status: "error"; error: unknown; retry: () => void }
  | { status: "ready"; accountId: string; state: SyncState };

/** Who is signed in, then their entities from the changes feed. */
export function useYours(): Yours {
  const account = useQuery(currentAccountQuery);
  const accountId = account.data?.id ?? null;
  const sync = useSyncState(accountId);
  const onSessionProblem = useSessionProblem();
  const syncError = sync.error;
  useEffect(() => {
    if (syncError !== null) onSessionProblem(syncError);
  }, [syncError, onSessionProblem]);

  if (account.isPending) return { status: "loading" };
  if (account.isError) {
    return { status: "error", error: account.error, retry: () => void account.refetch() };
  }
  if (accountId === null) return { status: "signedOut" };
  if (sync.isError) return { status: "error", error: sync.error, retry: () => void sync.refetch() };
  if (sync.data === undefined) return { status: "loading" };
  return { status: "ready", accountId, state: sync.data };
}

/** A per-language text in `language`, then English, then any language (sync README, custom dhikr). */
export function pickText(text: Partial<Languages3>, language: Language): string | null {
  return text[language] ?? text.en ?? text.ar ?? text.ml ?? null;
}

/**
 * A custom dhikr in the catalog's shape, so rows, the detail and search show it like a built-in.
 * Its ID is its key. Each text falls back from the UI language to English to any language; a
 * text it doesn't have at all is empty, and the detail leaves its section out. It has no virtues,
 * no catalog tags, and never audio on the web.
 */
export function asDhikr({ id, document }: Entity<CustomDhikrDocument>): Dhikr {
  const { title, transliteration, translation } = document;
  const titleIn = (language: Language) => pickText(title, language) ?? "";
  return {
    id,
    key: id,
    kind: document.kind,
    arabic: document.arabic,
    title: { en: titleIn("en"), ar: titleIn("ar"), ml: titleIn("ml") },
    transliteration: {
      en: transliteration.en ?? transliteration.ml ?? "",
      ...(transliteration.ml === null ? {} : { ml: transliteration.ml }),
    },
    translation: {
      en: translation.en ?? translation.ar ?? translation.ml ?? "",
      ...(translation.ar === null ? {} : { ar: translation.ar }),
      ...(translation.ml === null ? {} : { ml: translation.ml }),
    },
    audio: null,
    references: document.references,
    virtues: [],
  };
}

/** The account's custom dhikrs as catalog-shaped dhikrs, newest first (IDs are UUIDv7). */
export function customDhikrs(state: SyncState): Dhikr[] {
  return Object.values(state.custom_dhikr)
    .sort((a, b) => (a.id < b.id ? 1 : -1))
    .map(asDhikr);
}

/** The account's tags, by name in the UI language's order. */
export function sortedTags(state: SyncState, language: Language): Entity<UserTagDocument>[] {
  const collator = new Intl.Collator(language);
  return Object.values(state.user_tag).sort((a, b) => collator.compare(a.document.name, b.document.name));
}

/** The IDs of a dhikr's tags (built-in or custom), in the user's order, leaving out any since deleted. */
export function tagIdsOf(state: SyncState, dhikrId: string): string[] {
  return (state.dhikr_personal[dhikrId]?.document.tag_ids ?? []).filter((id) => id in state.user_tag);
}

/** The dhikrs that have every one of `tagIds` (AND); all of them when none is chosen. */
export function withAllTags(state: SyncState, dhikrs: readonly Dhikr[], tagIds: readonly string[]): Dhikr[] {
  return dhikrs.filter((dhikr) => {
    const tags = new Set(tagIdsOf(state, dhikr.id));
    return tagIds.every((id) => tags.has(id));
  });
}
