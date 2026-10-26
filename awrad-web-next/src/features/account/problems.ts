import { ApiProblem } from "@/shared/api/problem";

/** Problem codes the account screens explain (docs/slices/02-accounts.md). Anything else is "unexpected". */
const PROBLEM_CODES: ReadonlySet<string> = new Set([
  "validation_failed",
  "invalid_credentials",
  "email_verification_required",
  "verification_code_invalid",
  "reset_code_invalid",
  "csrf_token_invalid",
  "unauthenticated",
  "rate_limited",
]);

/** Field error codes from `validation_failed` (plus the client's own `code_invalid`). */
const FIELD_CODES: ReadonlySet<string> = new Set([
  "email_invalid",
  "password_too_short",
  "password_too_long",
  "password_too_common",
  "code_invalid",
]);

/** The translation key for a failed request, decided by `code` only, never by `detail`. */
export function problemKey(error: unknown): string {
  if (!(error instanceof ApiProblem)) return "account.problems.network";
  return PROBLEM_CODES.has(error.code) ? `account.problems.${error.code}` : "account.problems.unexpected";
}

export function fieldErrorKey(code: string): string {
  return FIELD_CODES.has(code) ? `account.fieldErrors.${code}` : "account.fieldErrors.invalid";
}

/**
 * Field errors keyed by the input's `name`, which is the JSON field name
 * (`/new_password` → `new_password`), so they land on the right input.
 */
export function fieldErrorKeys(error: unknown): Record<string, string> {
  if (!(error instanceof ApiProblem)) return {};
  const keys: Record<string, string> = {};
  for (const field of error.errors) keys[field.field.replace(/^\//, "")] = fieldErrorKey(field.code);
  return keys;
}
