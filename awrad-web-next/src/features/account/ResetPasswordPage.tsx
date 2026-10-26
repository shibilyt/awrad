import { useQueryClient } from "@tanstack/react-query";
import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { TextLink } from "@/shared/ui/TextLink";
import { AccountForm, AccountScreen } from "./AccountScreen";
import { currentAccountQuery, requestPasswordReset, resetPassword } from "./api";
import { CodeField, EmailField, NewPasswordField } from "./fields";
import { readCode, readEmail, readNewPassword } from "./formValues";
import { readPending } from "./pending";
import { CodeSentIntro, ResendCode } from "./ResendCode";
import { RESEND_COOLDOWN_SECONDS } from "./useCooldown";
import { signInAfter, useFinishSignIn } from "./useSignedIn";
import { useAccountAction } from "./useAccountAction";

interface Reset {
  email: string;
  code: string;
  newPassword: string;
}

/**
 * Enter the reset code and a new password. A reset signs out every session,
 * this browser's too, so the page then signs in with the new password.
 */
export function ResetPasswordPage(): ReactElement {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [pending] = useState(readPending);
  const [email, setEmail] = useState(pending?.email ?? "");
  const finish = useFinishSignIn("password_reset");

  const reset = useAccountAction({
    action: async ({ email, code, newPassword }: Reset) => {
      await resetPassword(email, code, newPassword);
      queryClient.setQueryData(currentAccountQuery.queryKey, null);
      return signInAfter(email, newPassword);
    },
    onSuccess: (account, { email }) => {
      finish(account, email);
    },
  });

  const submit = (data: FormData) => {
    const errors: Record<string, string> = {};
    const address = pending === null ? readEmail(data, errors) : pending.email;
    const code = readCode(data, errors);
    const newPassword = readNewPassword(data, "new_password", errors);
    reset.submit({ email: address, code, newPassword }, errors);
  };

  return (
    <AccountScreen
      title={t("account.reset.title")}
      intro={
        <>
          <CodeSentIntro pending={pending} fallback={t("account.reset.enterEmail")} />
          <p>{t("account.reset.signsOutEverywhere")}</p>
        </>
      }
      footer={<TextLink to="/sign-in">{t("account.backToSignIn")}</TextLink>}
    >
      <AccountForm
        errors={reset.errors}
        alert={reset.alert}
        submitLabel={t("account.reset.submit")}
        isPending={reset.isPending}
        onSubmit={submit}
      >
        {pending === null && <EmailField value={email} onChange={setEmail} />}
        <CodeField />
        <NewPasswordField name="new_password" label={t("account.fields.newPassword")} />
      </AccountForm>
      <ResendCode
        email={email}
        send={requestPasswordReset}
        initialCooldown={pending === null ? 0 : RESEND_COOLDOWN_SECONDS}
      />
    </AccountScreen>
  );
}
