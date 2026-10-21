import type { ReactElement } from "react";
import { Button } from "react-aria-components";
import { useTranslation } from "react-i18next";
import { LANGUAGES, isLanguage } from "@/shared/i18n";
import { PrimaryButton } from "@/shared/ui/Button";
import { LogoMark } from "@/shared/ui/LogoMark";
import { useBrowserSession } from "./useBrowserSession";

/** Placeholder home: proves the generated client, problem handling, i18n and RTL end to end. */
export function WelcomePage(): ReactElement {
  const { t, i18n } = useTranslation();
  const session = useBrowserSession();

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center gap-7 px-7 text-center">
      <LogoMark />
      <h1 className="text-3xl font-semibold text-primary">{t("app.title")}</h1>
      <p role="status" className="text-on-surface-variant">
        {t(`session.${session.status}`)}
      </p>
      {session.status === "unavailable" && <PrimaryButton onPress={session.retry}>{t("session.retry")}</PrimaryButton>}
      <nav aria-label={t("app.language")} className="flex gap-2">
        {LANGUAGES.map((language) => (
          <Button
            key={language}
            onPress={() => void i18n.changeLanguage(language)}
            aria-pressed={isLanguage(i18n.language) && i18n.language === language}
            className="rounded-full border border-outline-variant px-4 py-2 text-sm aria-pressed:border-primary aria-pressed:bg-primary-container aria-pressed:text-on-primary-container"
          >
            {t(`language.${language}`)}
          </Button>
        ))}
      </nav>
    </main>
  );
}
