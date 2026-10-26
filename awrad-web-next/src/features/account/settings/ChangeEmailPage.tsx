import { useNavigate } from "@tanstack/react-router";
import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { AccountForm } from "../AccountScreen";
import { CurrentPasswordField, EmailField } from "../fields";
import { readCurrentPassword, readEmail } from "../formValues";
import { useSignedInAccount } from "./AccountArea";
import { requestEmailChange } from "./api";
import { rememberEmailChange, type PendingEmailChange } from "./pendingEmailChange";
import { SettingsScreen } from "./SettingsScreen";
import { useSettingsAction } from "./useSettingsAction";

/**
 * Change the email, step one: the password and the new address. A code goes
 * to the new address; nothing changes until it's entered on the next page.
 */
export function ChangeEmailPage(): ReactElement {
  const { t } = useTranslation();
  const account = useSignedInAccount();
  const navigate = useNavigate();

  const request = useSettingsAction({
    action: ({ currentPassword, newEmail }: PendingEmailChange) => requestEmailChange(currentPassword, newEmail),
    onSuccess: (_, change) => {
      rememberEmailChange(change);
      void navigate({ to: "/account/email/confirm" });
    },
  });

  const submit = (data: FormData) => {
    const errors: Record<string, string> = {};
    const currentPassword = readCurrentPassword(data, errors);
    const newEmail = readEmail(data, errors, "new_email");
    request.submit({ currentPassword, newEmail }, errors);
  };

  return (
    <SettingsScreen
      title={t("account.email.title")}
      intro={
        <>
          <p>{t("account.email.intro")}</p>
          <p>
            {t("account.email.current")} <bdi className="font-semibold text-on-surface">{account.email}</bdi>
          </p>
        </>
      }
    >
      <AccountForm
        errors={request.errors}
        alert={request.alert}
        submitLabel={t("account.email.submit")}
        isPending={request.isPending}
        onSubmit={submit}
      >
        <CurrentPasswordField />
        <EmailField name="new_email" label={t("account.fields.newEmail")} />
      </AccountForm>
    </SettingsScreen>
  );
}
