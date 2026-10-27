import type { ReactElement, ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { LanguagePicker } from "./LanguagePicker";
import { TextLink } from "./TextLink";
import { TopBar } from "./TopBar";

/** The frame around every page: a top bar with the app name (home) and the language picker. */
export function AppShell({ children }: { children: ReactNode }): ReactElement {
  const { t } = useTranslation();
  return (
    <div className="flex min-h-dvh flex-col">
      <header>
        <TopBar
          start={
            <TextLink to="/" className="text-card-title">
              {t("app.name")}
            </TextLink>
          }
          end={<LanguagePicker />}
        />
      </header>
      <div className="page-transition flex flex-col">{children}</div>
    </div>
  );
}
