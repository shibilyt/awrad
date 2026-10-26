import { useQueryClient } from "@tanstack/react-query";
import { getRouteApi, useNavigate } from "@tanstack/react-router";
import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { ApiProblem } from "@/shared/api/problem";
import { Checkbox } from "@/shared/ui/Checkbox";
import { TextField } from "@/shared/ui/TextField";
import { TextLink } from "@/shared/ui/TextLink";
import { AccountForm, AccountScreen, FormNotice } from "./AccountScreen";
import { createBrowserSession, currentAccountQuery } from "./api";
import { readEmail, readPassword, text } from "./formValues";
import { forgetPending, readPending, rememberPending } from "./pending";
import { EmailField } from "./fields";
import { useAccountAction } from "./useAccountAction";

const route = getRouteApi("/sign-in");

interface SignIn {
  email: string;
  password: string;
  rememberMe: boolean;
}

export function SignInPage(): ReactElement {
  const { t } = useTranslation();
  const { notice } = route.useSearch();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [initialEmail] = useState(() => readPending()?.email ?? "");

  const signIn = useAccountAction({
    action: ({ email, password, rememberMe }: SignIn) => createBrowserSession(email, password, rememberMe),
    onSuccess: (account) => {
      forgetPending();
      queryClient.setQueryData(currentAccountQuery.queryKey, account);
      void navigate({ to: "/account" });
    },
    onProblem: (error, { email, password }) => {
      if (!(error instanceof ApiProblem) || error.code !== "email_verification_required") return false;
      // The server has emailed a fresh code; verify, then sign in with this password.
      rememberPending({ email, password });
      void navigate({ to: "/verify-email" });
      return true;
    },
  });

  const submit = (data: FormData) => {
    const errors: Record<string, string> = {};
    const email = readEmail(data, errors);
    const password = readPassword(data, errors);
    signIn.submit({ email, password, rememberMe: text(data, "remember_me") !== "" }, errors);
  };

  return (
    <AccountScreen
      title={t("account.signIn.title")}
      footer={
        <>
          <TextLink to="/forgot-password">{t("account.signIn.forgot")}</TextLink>
          <p>
            {t("account.signIn.noAccount")} <TextLink to="/register">{t("account.signIn.register")}</TextLink>
          </p>
        </>
      }
    >
      <FormNotice message={notice === undefined ? null : t(`account.signIn.notice.${notice}`)} />
      <AccountForm
        errors={signIn.errors}
        alert={signIn.alert}
        submitLabel={t("account.signIn.submit")}
        isPending={signIn.isPending}
        onSubmit={submit}
      >
        <EmailField defaultValue={initialEmail} />
        <TextField
          name="password"
          type="password"
          autoComplete="current-password"
          label={t("account.fields.password")}
        />
        <Checkbox name="remember_me" value="true" defaultSelected>
          {t("account.fields.rememberMe")}
        </Checkbox>
      </AccountForm>
    </AccountScreen>
  );
}
