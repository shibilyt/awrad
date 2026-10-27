import { useMutation, useQueryClient } from "@tanstack/react-query";
import { getRouteApi, useNavigate } from "@tanstack/react-router";
import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { SecondaryButton } from "@/shared/ui/Button";
import { TextLink } from "@/shared/ui/TextLink";
import { AccountScreen, FormAlert, FormNotice } from "./AccountScreen";
import { deleteBrowserSession, type Account } from "./api";
import { problemKey } from "./problems";
import { useSignedInAccount } from "./settings/AccountArea";
import { forgetAccount } from "./settings/api";

const route = getRouteApi("/account/");

function SignOut(): ReactElement {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const [alert, setAlert] = useState<string | null>(null);
  const signOut = useMutation({
    mutationFn: deleteBrowserSession,
    onSuccess: async () => {
      // Leave first: the account area sends a signed-out visitor to sign in, not home.
      await navigate({ to: "/" });
      forgetAccount(queryClient);
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

/** Links to the account settings (slice 2b). */
function Settings(): ReactElement {
  const { t } = useTranslation();
  const linkClass = "flex min-h-12 items-center px-5";
  return (
    <nav aria-label={t("account.page.settings")}>
      <ul className="flex flex-col rounded-2xl bg-surface">
        <li>
          <TextLink to="/account/devices" className={linkClass}>
            {t("account.page.devices")}
          </TextLink>
        </li>
        <li>
          <TextLink to="/account/password" className={linkClass}>
            {t("account.page.changePassword")}
          </TextLink>
        </li>
        <li>
          <TextLink to="/account/email" className={linkClass}>
            {t("account.page.changeEmail")}
          </TextLink>
        </li>
        <li>
          <TextLink to="/account/delete" className={`${linkClass} text-error!`}>
            {t("account.page.deleteAccount")}
          </TextLink>
        </li>
      </ul>
    </nav>
  );
}

/** The signed-in account: its email, the settings, and sign out. */
export function AccountPage(): ReactElement {
  const { t } = useTranslation();
  const account = useSignedInAccount();
  const { notice } = route.useSearch();

  return (
    <AccountScreen title={t("account.page.title")}>
      <FormNotice message={notice === undefined ? null : t(`account.page.notice.${notice}`)} />
      <AccountDetails account={account} />
      <Settings />
      <SignOut />
    </AccountScreen>
  );
}
