import i18next from "i18next";
import { initReactI18next } from "react-i18next";
import ar from "./locales/ar.json";
import en from "./locales/en.json";
import ml from "./locales/ml.json";

export const LANGUAGES = ["en", "ar", "ml"] as const;
export type Language = (typeof LANGUAGES)[number];

const RTL: ReadonlySet<Language> = new Set(["ar"]);

/** Sets `<html lang dir>` so the whole page, CSS logical properties included, follows the language. */
export function applyDocumentLanguage(language: Language): void {
  document.documentElement.lang = language;
  document.documentElement.dir = RTL.has(language) ? "rtl" : "ltr";
}

export function isLanguage(value: string): value is Language {
  return (LANGUAGES as readonly string[]).includes(value);
}

export async function initI18n(language: Language = "en"): Promise<void> {
  await i18next.use(initReactI18next).init({
    resources: { en: { translation: en }, ar: { translation: ar }, ml: { translation: ml } },
    lng: language,
    fallbackLng: "en",
    interpolation: { escapeValue: false },
    returnNull: false,
  });
  applyDocumentLanguage(language);
  i18next.on("languageChanged", (next) => {
    if (isLanguage(next)) applyDocumentLanguage(next);
  });
}
