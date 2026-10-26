import type { ReactElement, ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { LanguagePicker } from "./LanguagePicker";
import { TextLink } from "./TextLink";

/** The frame around every page: the app name (home) and the language picker. */
export function AppShell({ children }: { children: ReactNode }): ReactElement {
  const { t } = useTranslation();
  return (
    <div className="flex min-h-dvh flex-col">
      <header className="flex flex-wrap items-center justify-between gap-3 px-6 py-4">
        <TextLink to="/" className="text-lg">
          {t("app.name")}
        </TextLink>
        <LanguagePicker />
      </header>
      {children}
    </div>
  );
}
