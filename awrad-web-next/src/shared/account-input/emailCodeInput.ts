import { codePoints, isWhitespace } from "./whitespace";

/** Zero of each digit script a typed code may use: Arabic-Indic, Eastern Arabic-Indic, fullwidth. */
const DIGIT_ZEROS = [0x0660, 0x06f0, 0xff10] as const;

function asciiDigit(character: string): string {
  const point = character.codePointAt(0) ?? 0;
  for (const zero of DIGIT_ZEROS) {
    if (point >= zero && point <= zero + 9) return String(point - zero);
  }
  return character;
}

/**
 * What the client sends for a typed 6-digit code (contracts/account-model/v1
 * `email_code_input`): whitespace and hyphens removed, other digit scripts
 * converted to ASCII. `null` when the result isn't exactly six ASCII digits.
 */
export function emailCodeInput(input: string): string | null {
  const code = codePoints(input)
    .filter((character) => character !== "-" && !isWhitespace(character))
    .map(asciiDigit)
    .join("");
  return /^[0-9]{6}$/.test(code) ? code : null;
}
