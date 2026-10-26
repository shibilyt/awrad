import { useQuery } from "@tanstack/react-query";
import { Navigate, Outlet } from "@tanstack/react-router";
import { createContext, use, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { PrimaryButton } from "@/shared/ui/Button";
import { AccountScreen, FormAlert } from "../AccountScreen";
import { currentAccountQuery, type Account } from "../api";
import { problemKey } from "../problems";

const SignedInAccount = createContext<Account | null>(null);

/** The signed-in account, inside the account area (`/account/...`). */
export function useSignedInAccount(): Account {
  const account = use(SignedInAccount);
  if (account === null) throw new Error("useSignedInAccount is used outside the account area");
  return account;
}

/**
 * The account area's frame: every page under `/account` needs a signed-in
 * account. Signed out (or signed out meanwhile), it goes to sign in.
 */
export function AccountArea(): ReactElement {
  const { t } = useTranslation();
  const account = useQuery(currentAccountQuery);

  if (account.data === null) return <Navigate to="/sign-in" />;
  if (account.data !== undefined) {
    return (
      <SignedInAccount value={account.data}>
        <Outlet />
      </SignedInAccount>
    );
  }
  return (
    <AccountScreen title={t("account.page.title")}>
      {account.isError ? (
        <>
          <FormAlert message={t(problemKey(account.error))} />
          <PrimaryButton onPress={() => void account.refetch()}>{t("account.page.retry")}</PrimaryButton>
        </>
      ) : (
        <p role="status">{t("account.page.loading")}</p>
      )}
    </AccountScreen>
  );
}
