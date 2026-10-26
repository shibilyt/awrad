import { useQuery } from "@tanstack/react-query";
import { getRouteApi } from "@tanstack/react-router";
import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { PrimaryButton } from "@/shared/ui/Button";
import { LogoMark } from "@/shared/ui/LogoMark";
import { TextLink } from "@/shared/ui/TextLink";
import { FormNotice } from "./AccountScreen";
import { currentAccountQuery } from "./api";

const route = getRouteApi("/");

function SessionStatus(): ReactElement {
  const { t } = useTranslation();
  const account = useQuery(currentAccountQuery);

  if (account.isPending) return <p role="status">{t("home.checking")}</p>;
  if (account.isError) {
    return (
      <>
        <p role="alert">{t("home.unavailable")}</p>
        <PrimaryButton onPress={() => void account.refetch()}>{t("home.retry")}</PrimaryButton>
      </>
    );
  }
  if (account.data === null) {
    return (
      <>
        <p className="text-on-surface-variant">{t("home.signedOut")}</p>
        <div className="flex gap-6">
          <TextLink to="/sign-in">{t("home.signIn")}</TextLink>
          <TextLink to="/register">{t("home.register")}</TextLink>
        </div>
      </>
    );
  }
  return (
    <>
      <p className="text-on-surface-variant">
        {t("home.signedIn")} <bdi className="font-semibold text-on-surface">{account.data.email}</bdi>
      </p>
      <TextLink to="/account">{t("home.openAccount")}</TextLink>
    </>
  );
}

/** Home: a greeting and where this browser's session stands, from `get_current_account`. */
export function WelcomePage(): ReactElement {
  const { t } = useTranslation();
  const { notice } = route.useSearch();
  return (
    <main className="mx-auto flex max-w-md flex-col items-center gap-6 px-7 py-12 text-center">
      <LogoMark />
      <h1 className="text-3xl font-semibold text-accent">{t("app.title")}</h1>
      <FormNotice message={notice === undefined ? null : t(`home.notice.${notice}`)} />
      <SessionStatus />
    </main>
  );
}
