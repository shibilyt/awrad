/**
 * Tag names (contracts/sync/v1/fixtures/tag_name_normalization.json): what the user typed becomes
 * a display `name` and a `normalized_name`, the key two tags are compared by. The server
 * recomputes both and rejects a `user_tag` document that differs, so the client computes them the
 * same way before sending.
 */

export type TagNameProblem = "empty" | "too_many_graphemes" | "too_many_bytes";

export type TagName =
  | { accepted: true; name: string; normalized_name: string; reason: null }
  | { accepted: false; name: null; normalized_name: null; reason: TagNameProblem };

export const TAG_NAME_MAX_GRAPHEMES = 40;
export const TAG_NAME_MAX_BYTES = 128;

const WHITE_SPACE_RUN = /\p{White_Space}+/gu;
const graphemes = new Intl.Segmenter(undefined, { granularity: "grapheme" });
const utf8 = new TextEncoder();

/**
 * Unicode Default Case Folding (full, not locale-specific) of one code point. Upper-casing then
 * lower-casing (twice, so ẞ → ß → ss) matches CaseFolding.txt's C and F mappings except where
 * folding keeps or picks the upper case: dotless ı stays, and Cherokee folds to its upper case.
 */
function foldCodePoint(character: string): string {
  const code = character.codePointAt(0) ?? 0;
  if (code === 0x0131) return character;
  if (code >= 0x13a0 && code <= 0x13f5) return character;
  if (code >= 0x13f8 && code <= 0x13fd) return String.fromCodePoint(code - 8);
  if (code >= 0xab70 && code <= 0xabbf) return String.fromCodePoint(code - 0xab70 + 0x13a0);
  // One code point at a time, so the context-dependent final sigma never applies: Σ and ς both fold to σ.
  return Array.from(character.toUpperCase().toLowerCase(), (part) => part.toUpperCase().toLowerCase()).join("");
}

/** Full Unicode case folding: `Straße` and `STRASSE` both become `strasse`. */
export function caseFold(text: string): string {
  return Array.from(text, foldCodePoint).join("");
}

/** The display form: trimmed, each inner run of White_Space one space, NFC. */
export function tagDisplayName(input: string): string {
  // Not `trim()`, which also strips characters outside White_Space (U+FEFF).
  return input.replace(WHITE_SPACE_RUN, " ").replace(/^ | $/g, "").normalize("NFC");
}

/** Extended grapheme clusters, as the platform's Unicode segmentation counts them. */
export function graphemeCount(text: string): number {
  return Array.from(graphemes.segment(text)).length;
}

/**
 * The tag name for what the user typed, or why it can't be one: empty after trimming, more than
 * 40 graphemes, or more than 128 UTF-8 bytes, checked in that order.
 */
export function normalizeTagName(input: string): TagName {
  const name = tagDisplayName(input);
  const reason: TagNameProblem | null =
    name === ""
      ? "empty"
      : graphemeCount(name) > TAG_NAME_MAX_GRAPHEMES
        ? "too_many_graphemes"
        : utf8.encode(name).length > TAG_NAME_MAX_BYTES
          ? "too_many_bytes"
          : null;
  if (reason !== null) return { accepted: false, name: null, normalized_name: null, reason };
  return { accepted: true, name, normalized_name: caseFold(name).normalize("NFC"), reason: null };
}
