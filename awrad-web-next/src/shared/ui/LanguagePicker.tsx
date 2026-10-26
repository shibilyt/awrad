import type { ReactElement } from "react";
import { Button } from "react-aria-components";
import { useTranslation } from "react-i18next";
import { LANGUAGES, isLanguage } from "@/shared/i18n";

/** Switches the UI language; `<html lang dir>` and `Accept-Language` follow it. */
export function LanguagePicker(): ReactElement {
  const { t, i18n } = useTranslation();
  return (
    <nav aria-label={t("app.language")} className="flex gap-2">
      {LANGUAGES.map((language) => (
        <Button
          key={language}
          onPress={() => void i18n.changeLanguage(language)}
          aria-pressed={isLanguage(i18n.language) && i18n.language === language}
          className="rounded-full border border-outline-variant px-3 py-1.5 text-sm aria-pressed:border-primary aria-pressed:bg-primary-container aria-pressed:text-on-primary-container"
        >
          {t(`language.${language}`)}
        </Button>
      ))}
    </nav>
  );
}
