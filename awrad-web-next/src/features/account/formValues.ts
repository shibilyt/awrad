import { emailCodeInput, emailInput, passwordErrors } from "@/shared/account-input";
import { fieldErrorKey } from "./problems";

/**
 * Reads form fields through the shared input rules (contracts/account-model/v1).
 * A failed rule records a translation key under the input's name in `errors`.
 */
export function text(data: FormData, name: string): string {
  const value = data.get(name);
  return typeof value === "string" ? value : "";
}

export function readEmail(data: FormData, errors: Record<string, string>, name = "email"): string {
  const email = emailInput(text(data, name));
  if (email === null) errors[name] = fieldErrorKey("email_invalid");
  return email ?? "";
}

/** The current password, re-entered to confirm a sensitive change: only required. */
export function readCurrentPassword(data: FormData, errors: Record<string, string>): string {
  const password = text(data, "current_password");
  if (password === "") errors["current_password"] = "account.fieldErrors.current_password_required";
  return password;
}

/** A password being chosen: the shared length rule. The server also rejects common ones. */
export function readNewPassword(data: FormData, name: string, errors: Record<string, string>): string {
  const password = text(data, name);
  const [error] = passwordErrors(password);
  if (error !== undefined) errors[name] = fieldErrorKey(error);
  return password;
}

/** A password to sign in with: only required. Length rules apply when choosing one. */
export function readPassword(data: FormData, errors: Record<string, string>): string {
  const password = text(data, "password");
  if (password === "") errors["password"] = "account.fieldErrors.password_required";
  return password;
}

export function readCode(data: FormData, errors: Record<string, string>): string {
  const code = emailCodeInput(text(data, "code"));
  if (code === null) errors["code"] = fieldErrorKey("code_invalid");
  return code ?? "";
}
