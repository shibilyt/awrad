import { useQuery } from "@tanstack/react-query";
import { getRouteApi } from "@tanstack/react-router";
import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { Button } from "@/shared/ui/Button";
import { LogoMark } from "@/shared/ui/LogoMark";
import { TextLink } from "@/shared/ui/TextLink";
import { FormNotice } from "./AccountScreen";
import { currentAccountQuery } from "./api";

const route = getRouteApi("/");

function SessionStatusContent(): ReactElement {
  const { t } = useTranslation();
  const account = useQuery(currentAccountQuery);

  if (account.isPending) return <p role="status">{t("home.checking")}</p>;
  if (account.isError) {
    return (
      <>
        <p role="alert">{t("home.unavailable")}</p>
        <Button onPress={() => void account.refetch()}>{t("home.retry")}</Button>
      </>
    );
  }
  if (account.data === null) {
    return (
      <>
        <p className="text-on-surface-variant">{t("home.signedOut")}</p>
        <div className="flex gap-2xl">
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

/** Where this browser's session stands. Each state fades in as it replaces "Checking…" (`content-swap`). */
function SessionStatus(): ReactElement {
  const account = useQuery(currentAccountQuery);
  const state = account.isPending
    ? "checking"
    : account.isError
      ? "unavailable"
      : account.data === null
        ? "signedOut"
        : "signedIn";
  return (
    <div key={state} className="content-swap flex flex-col items-center gap-2xl">
      <SessionStatusContent />
    </div>
  );
}

/** Home: a greeting and where this browser's session stands, from `get_current_account`. */
export function WelcomePage(): ReactElement {
  const { t } = useTranslation();
  const { notice } = route.useSearch();
  return (
    <main className="mx-auto flex max-w-content flex-col items-center gap-2xl px-page-margin py-5xl text-center">
      <LogoMark />
      <h1 className="text-title text-on-surface">{t("app.title")}</h1>
      <FormNotice message={notice === undefined ? null : t(`home.notice.${notice}`)} />
      <SessionStatus />
    </main>
  );
}
