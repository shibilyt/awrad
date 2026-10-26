import type { ReactElement } from "react";
import { Button } from "react-aria-components";
import { useTranslation } from "react-i18next";
import { LANGUAGES, isLanguage } from "@/shared/i18n";
import { useFill } from "./Surface";

/**
 * Switches the UI language; `<html lang dir>` and `Accept-Language` follow it.
 * The pills are filled, never outlined; the selected one is `primary-container`.
 */
export function LanguagePicker(): ReactElement {
  const { t, i18n } = useTranslation();
  const fill = useFill();
  return (
    <nav aria-label={t("app.language")} className="flex gap-2">
      {LANGUAGES.map((language) => (
        <Button
          key={language}
          onPress={() => void i18n.changeLanguage(language)}
          aria-pressed={isLanguage(i18n.language) && i18n.language === language}
          className={[
            "focus-ring rounded-full px-3 py-1.5 text-sm",
            fill,
            "aria-pressed:bg-primary-container aria-pressed:text-on-primary-container",
          ].join(" ")}
        >
          {t(`language.${language}`)}
        </Button>
      ))}
    </nav>
  );
}
