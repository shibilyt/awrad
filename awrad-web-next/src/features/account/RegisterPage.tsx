import { useNavigate } from "@tanstack/react-router";
import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { TextLink } from "@/shared/ui/TextLink";
import { AccountForm, AccountScreen } from "./AccountScreen";
import { registerAccount } from "./api";
import { EmailField, NewPasswordField } from "./fields";
import { readEmail, readNewPassword } from "./formValues";
import { rememberPending } from "./pending";
import { useAccountAction } from "./useAccountAction";

interface Registration {
  email: string;
  password: string;
}

/** Create an account: verification-first, so the next screen asks for the emailed code. */
export function RegisterPage(): ReactElement {
  const { t } = useTranslation();
  const navigate = useNavigate();

  const register = useAccountAction({
    action: ({ email, password }: Registration) => registerAccount(email, password),
    onSuccess: (_result, registration) => {
      // Always 202, also for an existing email (it isn't revealed). Verify, then sign in with this password.
      rememberPending(registration);
      void navigate({ to: "/verify-email" });
    },
  });

  const submit = (data: FormData) => {
    const errors: Record<string, string> = {};
    const email = readEmail(data, errors);
    const password = readNewPassword(data, "password", errors);
    register.submit({ email, password }, errors);
  };

  return (
    <AccountScreen
      title={t("account.register.title")}
      intro={<p>{t("account.register.intro")}</p>}
      footer={
        <p>
          {t("account.register.haveAccount")} <TextLink to="/sign-in">{t("account.register.signIn")}</TextLink>
        </p>
      }
    >
      <AccountForm
        errors={register.errors}
        alert={register.alert}
        submitLabel={t("account.register.submit")}
        isPending={register.isPending}
        onSubmit={submit}
      >
        <EmailField />
        <NewPasswordField name="password" label={t("account.fields.password")} />
      </AccountForm>
    </AccountScreen>
  );
}
