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
export function EmailField(props: FieldProps): ReactElement {
  const { t } = useTranslation();
  return (
    <TextField
      {...props}
      name="email"
      inputMode="email"
      autoComplete="email"
      autoCapitalize="none"
      spellCheck="false"
      label={t("account.fields.email")}
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
