import type { Language } from "@/shared/i18n";
import type { Dhikr, LocalText } from "./types";

/** `text` in `language`, or the English text when that language has none. */
export function localized(text: LocalText, language: Language): string {
  return text[language] ?? text.en;
}

/**
 * The transliteration to show in `language`, in that language's script, falling back to English.
 * Arabic shows none: the text is already Arabic.
 */
export function transliterationFor(dhikr: Dhikr, language: Language): string | null {
  if (language === "ar") return null;
  return language === "ml" ? (dhikr.transliteration.ml ?? dhikr.transliteration.en) : dhikr.transliteration.en;
}
