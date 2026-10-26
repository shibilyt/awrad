import { codePoints } from "./whitespace";

export const PASSWORD_MIN_LENGTH = 12;
export const PASSWORD_MAX_LENGTH = 128;

export type PasswordError = "password_too_short" | "password_too_long";

/**
 * The shared password length rule (contracts/account-model/v1
 * `password_policy`): 12 to 128 Unicode code points after NFC. Nothing is
 * trimmed and there are no composition rules. Not `string.length`, which
 * counts UTF-16 units. The server also rejects common passwords.
 */
export function passwordErrors(password: string): PasswordError[] {
  const length = codePoints(password.normalize("NFC")).length;
  if (length < PASSWORD_MIN_LENGTH) return ["password_too_short"];
  if (length > PASSWORD_MAX_LENGTH) return ["password_too_long"];
  return [];
}
