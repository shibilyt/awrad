import { useMutation, useQueryClient } from "@tanstack/react-query";
import { getRouteApi, useNavigate } from "@tanstack/react-router";
import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { Button } from "@/shared/ui/Button";
import { Card } from "@/shared/ui/Card";
import { cx } from "@/shared/ui/cx";
import {
  ChevronIcon,
  DeleteIcon,
  DevicesIcon,
  EmailIcon,
  PasswordIcon,
  type Icon as IconComponent,
} from "@/shared/ui/icons.gen";
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
    <div className="flex flex-col gap-row-gap">
      <FormAlert message={alert} />
      <Button
        variant="secondary"
        onPress={() => {
          setAlert(null);
          signOut.mutate();
        }}
        isPending={signOut.isPending}
      >
        {t("account.page.signOut")}
      </Button>
    </div>
  );
}

function AccountDetails({ account }: { account: Account }): ReactElement {
  const { t } = useTranslation();
  return (
    <Card>
      <dl className="flex flex-col gap-xs">
        <dt className="text-body-small text-on-surface-variant">{t("account.fields.email")}</dt>
        <dd className="text-row-title break-all">
          <bdi>{account.email}</bdi>
        </dd>
      </dl>
    </Card>
  );
}

/** A settings row: a leading icon, the label (the link's accessible name), then a trailing chevron. */
function SettingsLink({
  to,
  icon: LeadingIcon,
  label,
  destructive = false,
}: {
  to: "/account/devices" | "/account/password" | "/account/email" | "/account/delete";
  icon: IconComponent;
  label: string;
  destructive?: boolean;
}): ReactElement {
  return (
    <li>
      <TextLink
        to={to}
        className={cx(
          "flex min-h-list-row items-center gap-md px-card-padding text-row-title",
          destructive && "text-error!",
        )}
      >
        <LeadingIcon />
        <span className="min-w-0 flex-1">{label}</span>
        <ChevronIcon />
      </TextLink>
    </li>
  );
}

/** Links to the account settings (slice 2b). */
function Settings(): ReactElement {
  const { t } = useTranslation();
  return (
    <nav aria-label={t("account.page.settings")}>
      <Card padded={false}>
        <ul className="flex flex-col">
          <SettingsLink to="/account/devices" icon={DevicesIcon} label={t("account.page.devices")} />
          <SettingsLink to="/account/password" icon={PasswordIcon} label={t("account.page.changePassword")} />
          <SettingsLink to="/account/email" icon={EmailIcon} label={t("account.page.changeEmail")} />
          <SettingsLink to="/account/delete" icon={DeleteIcon} label={t("account.page.deleteAccount")} destructive />
        </ul>
      </Card>
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
