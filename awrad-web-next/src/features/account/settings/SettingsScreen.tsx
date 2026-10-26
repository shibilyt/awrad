import type { ReactElement, ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { TextLink } from "@/shared/ui/TextLink";
import { AccountScreen } from "../AccountScreen";

/** An account settings page: the account screen frame with a way back to the account. */
export function SettingsScreen({
  title,
  intro,
  children,
}: {
  title: string;
  intro?: ReactNode;
  children: ReactNode;
}): ReactElement {
  const { t } = useTranslation();
  return (
    <AccountScreen
      title={title}
      {...(intro === undefined ? {} : { intro })}
      footer={<TextLink to="/account">{t("account.backToAccount")}</TextLink>}
    >
      {children}
    </AccountScreen>
  );
}
