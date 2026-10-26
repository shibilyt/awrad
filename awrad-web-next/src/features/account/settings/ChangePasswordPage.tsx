import { useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { AccountForm } from "../AccountScreen";
import { CurrentPasswordField, NewPasswordField } from "../fields";
import { readCurrentPassword, readNewPassword } from "../formValues";
import { accountSessionsQuery, changePassword } from "./api";
import { SettingsScreen } from "./SettingsScreen";
import { useSettingsAction } from "./useSettingsAction";

interface PasswordChange {
  currentPassword: string;
  newPassword: string;
}

/** Change the password with the current one. Every other device and browser is signed out; this one stays. */
export function ChangePasswordPage(): ReactElement {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const navigate = useNavigate();

  const change = useSettingsAction({
    action: ({ currentPassword, newPassword }: PasswordChange) => changePassword(currentPassword, newPassword),
    onSuccess: () => {
      // The other sessions have ended, so the device list is stale.
      void queryClient.invalidateQueries({ queryKey: accountSessionsQuery.queryKey });
      void navigate({ to: "/account", search: { notice: "password_changed" } });
    },
  });

  const submit = (data: FormData) => {
    const errors: Record<string, string> = {};
    const currentPassword = readCurrentPassword(data, errors);
    const newPassword = readNewPassword(data, "new_password", errors);
    change.submit({ currentPassword, newPassword }, errors);
  };

  return (
    <SettingsScreen title={t("account.password.title")} intro={<p>{t("account.password.intro")}</p>}>
      <AccountForm
        errors={change.errors}
        alert={change.alert}
        submitLabel={t("account.password.submit")}
        isPending={change.isPending}
        onSubmit={submit}
      >
        <CurrentPasswordField />
        <NewPasswordField name="new_password" label={t("account.fields.newPassword")} />
      </AccountForm>
    </SettingsScreen>
  );
}
