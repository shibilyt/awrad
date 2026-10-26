/**
 * Whitespace for account input (contracts/account-model/v1/README.md): Unicode
 * White_Space plus zero-width space and BOM, as an explicit set rather than a
 * platform `trim()`, so every client strips exactly the same characters.
 */
const WHITESPACE: ReadonlySet<number> = new Set([
  // Unicode White_Space
  0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x0020, 0x0085, 0x00a0, 0x1680, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004,
  0x2005, 0x2006, 0x2007, 0x2008, 0x2009, 0x200a, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000,
  // Zero-width space and byte order mark
  0x200b, 0xfeff,
]);

/**
 * The string's Unicode code points: the unit every account rule counts in
 * (not UTF-16 units like `length`, not grapheme clusters).
 */
export function codePoints(value: string): string[] {
  return Array.from(value);
}

export function isWhitespace(character: string): boolean {
  return WHITESPACE.has(character.codePointAt(0) ?? -1);
}

/** `value` without leading and trailing whitespace from the shared set. */
export function trimWhitespace(value: string): string {
  const characters = codePoints(value);
  let start = 0;
  let end = characters.length;
  while (start < end && isWhitespace(characters[start] ?? "")) start += 1;
  while (end > start && isWhitespace(characters[end - 1] ?? "")) end -= 1;
  return characters.slice(start, end).join("");
}
