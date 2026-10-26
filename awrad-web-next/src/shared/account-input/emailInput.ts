import { codePoints, isWhitespace, trimWhitespace } from "./whitespace";

/** The `Email` schema's limit, in code points. */
export const EMAIL_MAX_LENGTH = 160;

/**
 * What the client sends for a typed email (contracts/account-model/v1
 * `email_input`): trimmed, then a basic shape check. Case is kept. `null` means
 * don't send it; the server stays the authority.
 */
export function emailInput(input: string): string | null {
  const email = trimWhitespace(input);
  const characters = codePoints(email);
  if (characters.length === 0 || characters.length > EMAIL_MAX_LENGTH) return null;
  if (characters.some(isWhitespace)) return null;

  const parts = email.split("@");
  if (parts.length !== 2) return null;
  const [local = "", domain = ""] = parts;
  if (local === "") return null;
  const labels = domain.split(".");
  if (labels.length < 2 || labels.some((label) => label === "")) return null;
  return email;
}
