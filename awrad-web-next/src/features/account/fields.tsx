import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { PASSWORD_MIN_LENGTH } from "@/shared/account-input";
import { TextField, type TextFieldProps } from "@/shared/ui/TextField";

type FieldProps = Omit<TextFieldProps, "label" | "name">;

/**
 * The email input. A text input with the email keyboard rather than
 * `type="email"`, which some browsers rewrite (punycode) or trim differently;
 * the shared `email_input` rule decides what's sent.
 */
export function EmailField({
  name = "email",
  label,
  ...props
}: FieldProps & { name?: string; label?: string }): ReactElement {
  const { t } = useTranslation();
  return (
    <TextField
      {...props}
      name={name}
      inputMode="email"
      autoComplete="email"
      autoCapitalize="none"
      spellCheck="false"
      label={label ?? t("account.fields.email")}
    />
  );
}

/** The account's current password, re-entered to confirm a sensitive change. */
export function CurrentPasswordField(): ReactElement {
  const { t } = useTranslation();
  return (
    <TextField
      name="current_password"
      type="password"
      autoComplete="current-password"
      label={t("account.fields.currentPassword")}
    />
  );
}

/** A password being chosen, with the 12-character hint. */
export function NewPasswordField({ name, label }: { name: string; label: string }): ReactElement {
  const { t } = useTranslation();
  return (
    <TextField
      name={name}
      type="password"
      autoComplete="new-password"
      label={label}
      description={t("account.hints.password", { min: PASSWORD_MIN_LENGTH })}
    />
  );
}

/** The 6-digit emailed code. Any digit script, spaces and hyphens are fine (`email_code_input`). */
export function CodeField(): ReactElement {
  const { t } = useTranslation();
  return (
    <TextField
      name="code"
      inputMode="numeric"
      autoComplete="one-time-code"
      label={t("account.fields.code")}
      description={t("account.hints.code")}
    />
  );
}
