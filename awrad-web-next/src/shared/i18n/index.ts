import i18next from "i18next";
import { initReactI18next } from "react-i18next";
import ar from "./locales/ar.json";
import en from "./locales/en.json";
import ml from "./locales/ml.json";

export const LANGUAGES = ["en", "ar", "ml"] as const;
export type Language = (typeof LANGUAGES)[number];

const RTL: ReadonlySet<Language> = new Set(["ar"]);

/**
 * Where the chosen UI language is kept so it survives a reload. Only the
 * language code is stored: never credentials, tokens or account data.
 */
export const LANGUAGE_STORAGE_KEY = "awrad.language";

/** Sets `<html lang dir>` so the whole page, CSS logical properties included, follows the language. */
export function applyDocumentLanguage(language: Language): void {
  document.documentElement.lang = language;
  document.documentElement.dir = RTL.has(language) ? "rtl" : "ltr";
}

export function isLanguage(value: string): value is Language {
  return (LANGUAGES as readonly string[]).includes(value);
}

/** The language chosen on an earlier visit, or `null`. Storage can be unavailable (privacy modes). */
export function storedLanguage(): Language | null {
  try {
    const value = window.localStorage.getItem(LANGUAGE_STORAGE_KEY);
    return value !== null && isLanguage(value) ? value : null;
  } catch {
    return null;
  }
}

function storeLanguage(language: Language): void {
  try {
    window.localStorage.setItem(LANGUAGE_STORAGE_KEY, language);
  } catch {
    // Not remembered across reloads, but the page still switches.
  }
}

/**
 * Starts i18n in `language`: by default the one chosen on an earlier visit,
 * otherwise English. Every later change is remembered and applied to
 * `<html lang dir>`; the API client reads the same language for `Accept-Language`.
 */
export async function initI18n(language: Language = storedLanguage() ?? "en"): Promise<void> {
  await i18next.use(initReactI18next).init({
    resources: { en: { translation: en }, ar: { translation: ar }, ml: { translation: ml } },
    lng: language,
    fallbackLng: "en",
    interpolation: { escapeValue: false },
    returnNull: false,
  });
  applyDocumentLanguage(language);
  i18next.on("languageChanged", (next) => {
    if (!isLanguage(next)) return;
    applyDocumentLanguage(next);
    storeLanguage(next);
  });
}
