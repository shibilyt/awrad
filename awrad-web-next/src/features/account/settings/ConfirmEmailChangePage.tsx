import { useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { ApiProblem } from "@/shared/api/problem";
import { TextLink } from "@/shared/ui/TextLink";
import { AccountForm } from "../AccountScreen";
import { currentAccountQuery } from "../api";
import { CodeField } from "../fields";
import { readCode } from "../formValues";
import { CodeSentIntro, ResendCode } from "../ResendCode";
import { RESEND_COOLDOWN_SECONDS } from "../useCooldown";
import { confirmEmailChange, requestEmailChange } from "./api";
import { forgetEmailChange, readEmailChange } from "./pendingEmailChange";
import { isSessionEnded, useEndSession } from "./sessionEnded";
import { SettingsScreen } from "./SettingsScreen";
import { useSettingsAction } from "./useSettingsAction";

/**
 * Change the email, step two: the code sent to the new address. Sessions stay
 * signed in, so the account page then shows the new email. After a reload the
 * code still works; a new code means starting again from step one.
 */
export function ConfirmEmailChangePage(): ReactElement {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const endSession = useEndSession();
  const [pending, setPending] = useState(readEmailChange);

  const confirm = useSettingsAction({
    action: confirmEmailChange,
    onSuccess: (account) => {
      forgetEmailChange();
      queryClient.setQueryData(currentAccountQuery.queryKey, account);
      void navigate({ to: "/account", search: { notice: "email_changed" } });
    },
    onProblem: (error) => {
      // The address was taken meanwhile: this change can't finish, so a new code won't help.
      if (error instanceof ApiProblem && error.code === "email_taken") {
        forgetEmailChange();
        setPending(null);
      }
      return false;
    },
  });

  const resend = async (newEmail: string) => {
    if (pending === null) return;
    try {
      await requestEmailChange(pending.currentPassword, newEmail);
    } catch (error) {
      if (isSessionEnded(error)) void endSession();
      throw error;
    }
  };

  const submit = (data: FormData) => {
    const errors: Record<string, string> = {};
    const code = readCode(data, errors);
    confirm.submit(code, errors);
  };

  return (
    <SettingsScreen
      title={t("account.emailConfirm.title")}
      intro={
        <CodeSentIntro
          pending={pending === null ? null : { email: pending.newEmail, password: null }}
          fallback={t("account.emailConfirm.enterCode")}
        />
      }
    >
      <AccountForm
        errors={confirm.errors}
        alert={confirm.alert}
        submitLabel={t("account.emailConfirm.submit")}
        isPending={confirm.isPending}
        onSubmit={submit}
      >
        <CodeField />
      </AccountForm>
      {pending !== null && (
        <ResendCode email={pending.newEmail} send={resend} initialCooldown={RESEND_COOLDOWN_SECONDS} />
      )}
      <TextLink to="/account/email" className="self-start">
        {t("account.emailConfirm.startAgain")}
      </TextLink>
    </SettingsScreen>
  );
}
