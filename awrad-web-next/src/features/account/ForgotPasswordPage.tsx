import { useNavigate } from "@tanstack/react-router";
import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { TextLink } from "@/shared/ui/TextLink";
import { AccountForm, AccountScreen } from "./AccountScreen";
import { requestPasswordReset } from "./api";
import { EmailField } from "./fields";
import { readEmail } from "./formValues";
import { readPending, rememberPending } from "./pending";
import { useAccountAction } from "./useAccountAction";

/** Ask for a reset code. Always accepted, so it doesn't reveal whether the email has an account. */
export function ForgotPasswordPage(): ReactElement {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [initialEmail] = useState(() => readPending()?.email ?? "");

  const request = useAccountAction({
    action: (email: string) => requestPasswordReset(email),
    onSuccess: (_result, email) => {
      rememberPending({ email, password: null });
      void navigate({ to: "/reset-password" });
    },
  });

  const submit = (data: FormData) => {
    const errors: Record<string, string> = {};
    request.submit(readEmail(data, errors), errors);
  };

  return (
    <AccountScreen
      title={t("account.forgot.title")}
      intro={<p>{t("account.forgot.intro")}</p>}
      footer={<TextLink to="/sign-in">{t("account.backToSignIn")}</TextLink>}
    >
      <AccountForm
        errors={request.errors}
        alert={request.alert}
        submitLabel={t("account.forgot.submit")}
        isPending={request.isPending}
        onSubmit={submit}
      >
        <EmailField defaultValue={initialEmail} />
      </AccountForm>
    </AccountScreen>
  );
}
