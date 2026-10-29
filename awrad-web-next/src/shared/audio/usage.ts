import { queryOptions } from "@tanstack/react-query";
import { ACCOUNT_QUERY_KEY } from "@/shared/session";
import { getAudioUsage } from "./api";

function options(accountId: string) {
  return queryOptions({
    queryKey: [...ACCOUNT_QUERY_KEY, "audio-usage", accountId],
    queryFn: () => getAudioUsage(accountId),
    retry: false,
  });
}

/**
 * The account's audio storage in TanStack Query, under `ACCOUNT_QUERY_KEY` so signing out drops
 * it. An upload marks it stale (it counts pending uploads too).
 */
export function audioUsageQuery(accountId: string): ReturnType<typeof options> {
  return options(accountId);
}

/** Every account's usage query, to mark stale after an upload. */
export const AUDIO_USAGE_KEY = [...ACCOUNT_QUERY_KEY, "audio-usage"] as const;

/**
 * Bytes in decimal megabytes ("120.5 MB"), as the limits are written (README "Storage used"), in
 * the UI language's digits and unit.
 */
export function formatMegabytes(bytes: number, language: string): string {
  return new Intl.NumberFormat(language, {
    style: "unit",
    unit: "megabyte",
    unitDisplay: "short",
    maximumFractionDigits: 1,
  }).format(bytes / 1_000_000);
}
