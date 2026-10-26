import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Navigate, useNavigate } from "@tanstack/react-router";
import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { PrimaryButton, SecondaryButton } from "@/shared/ui/Button";
import { AccountScreen, FormAlert } from "./AccountScreen";
import { currentAccountQuery, deleteBrowserSession, type Account } from "./api";
import { problemKey } from "./problems";

function SignOut(): ReactElement {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const [alert, setAlert] = useState<string | null>(null);
  const signOut = useMutation({
    mutationFn: deleteBrowserSession,
    onSuccess: async () => {
      // Leave first: this page sends a signed-out visitor to sign in, not home.
      await navigate({ to: "/" });
      queryClient.setQueryData(currentAccountQuery.queryKey, null);
    },
    onError: (error) => {
      setAlert(t(problemKey(error)));
    },
  });

  return (
    <div className="flex flex-col gap-3">
      <FormAlert message={alert} />
      <SecondaryButton
        onPress={() => {
          setAlert(null);
          signOut.mutate();
        }}
        isPending={signOut.isPending}
      >
        {t("account.page.signOut")}
      </SecondaryButton>
    </div>
  );
}

function AccountDetails({ account }: { account: Account }): ReactElement {
  const { t } = useTranslation();
  return (
    <dl className="flex flex-col gap-1 rounded-2xl bg-surface p-5">
      <dt className="text-sm text-on-surface-variant">{t("account.fields.email")}</dt>
      <dd className="font-semibold break-all">
        <bdi>{account.email}</bdi>
      </dd>
    </dl>
  );
}

/** The signed-in account: its email, and sign out. Signed out, it goes to sign in. */
export function AccountPage(): ReactElement {
  const { t } = useTranslation();
  const account = useQuery(currentAccountQuery);

  if (account.data === null) return <Navigate to="/sign-in" />;
  return (
    <AccountScreen title={t("account.page.title")}>
      {account.isPending && <p role="status">{t("account.page.loading")}</p>}
      {account.isError && (
        <>
          <FormAlert message={t(problemKey(account.error))} />
          <PrimaryButton onPress={() => void account.refetch()}>{t("account.page.retry")}</PrimaryButton>
        </>
      )}
      {account.data !== undefined && (
        <>
          <AccountDetails account={account.data} />
          <SignOut />
        </>
      )}
    </AccountScreen>
  );
}
