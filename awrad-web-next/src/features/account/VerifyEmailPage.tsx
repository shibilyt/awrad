import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { TextLink } from "@/shared/ui/TextLink";
import { AccountForm, AccountScreen } from "./AccountScreen";
import { resendVerificationCode, verifyAccountEmail } from "./api";
import { CodeField, EmailField } from "./fields";
import { readCode, readEmail } from "./formValues";
import { readPending } from "./pending";
import { CodeSentIntro, ResendCode } from "./ResendCode";
import { RESEND_COOLDOWN_SECONDS } from "./useCooldown";
import { signInAfter, useFinishSignIn } from "./useSignedIn";
import { useAccountAction } from "./useAccountAction";

interface Verification {
  email: string;
  code: string;
}

/**
 * Enter the emailed code. Verifying doesn't sign in, so the page then signs in
 * with the password given on the screen before; without one (after a reload)
 * it sends the person to sign in.
 */
export function VerifyEmailPage(): ReactElement {
  const { t } = useTranslation();
  const [pending] = useState(readPending);
  const [email, setEmail] = useState(pending?.email ?? "");
  const finish = useFinishSignIn("verified");

  const verify = useAccountAction({
    action: async ({ email, code }: Verification) => {
      await verifyAccountEmail(email, code);
      return signInAfter(email, pending?.password ?? null);
    },
    onSuccess: (account, { email }) => {
      finish(account, email);
    },
  });

  const submit = (data: FormData) => {
    const errors: Record<string, string> = {};
    const address = pending === null ? readEmail(data, errors) : pending.email;
    const code = readCode(data, errors);
    verify.submit({ email: address, code }, errors);
  };

  return (
    <AccountScreen
      title={t("account.verify.title")}
      intro={<CodeSentIntro pending={pending} fallback={t("account.verify.enterEmail")} />}
      footer={<TextLink to="/sign-in">{t("account.backToSignIn")}</TextLink>}
    >
      <AccountForm
        errors={verify.errors}
        alert={verify.alert}
        submitLabel={t("account.verify.submit")}
        isPending={verify.isPending}
        onSubmit={submit}
      >
        {pending === null && <EmailField value={email} onChange={setEmail} />}
        <CodeField />
      </AccountForm>
      <ResendCode
        email={email}
        send={resendVerificationCode}
        initialCooldown={pending === null ? 0 : RESEND_COOLDOWN_SECONDS}
      />
    </AccountScreen>
  );
}
