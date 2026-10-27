import type { Language } from "@/shared/i18n";
import type { Catalog, Dhikr } from "./types";

/** Arabic harakat and marks, superscript alef, Qur'anic marks and tatweel. */
const ARABIC_MARKS = /[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]/g;
/** Every other combining mark, except Malayalam's signs, which are letters there. */
const OTHER_MARKS = /(?![\u0D00-\u0D7F])\p{M}/gu;
/** Alef with hamza above or below, with madda, and alef wasla. */
const ALEF_FORMS = /[\u0623\u0625\u0622\u0671]/g;
const ALEF = "\u0627";
const TA_MARBUTA = "\u0629";
const HA = "\u0647";
const ALEF_MAQSURA = "\u0649";
const YA = "\u064A";
/** ZWNJ and ZWJ. */
const ZERO_WIDTH_JOINERS = /[\u200C\u200D]/g;
const APOSTROPHES = /['\u2019\u02BC\u02BF\u02BE`]/g;
/** Hyphen, underscore, full stop, commas (Latin and Arabic), colon, semicolon, ! ? ( ) and quotes. */
const SEPARATORS = /[-_.,\u060C:;!?()"\u201C\u201D]/g;
const SPACES = /\s+/g;

/**
 * Text as dhikr search compares it (contracts/dhikr-catalog/v1/fixtures/
 * dhikr_search_normalization.json): without harakat, Qur'anic marks, tatweel, Latin
 * diacritics, apostrophes and zero-width joiners; with one alef, ta marbuta as ha and alef
 * maqsura as ya; punctuation as spaces; lower case; single spaces, trimmed.
 */
export function normalizeForSearch(text: string): string {
  return text
    .normalize("NFKD")
    .replace(ARABIC_MARKS, "")
    .replace(OTHER_MARKS, "")
    .normalize("NFC")
    .replace(ALEF_FORMS, ALEF)
    .replaceAll(TA_MARBUTA, HA)
    .replaceAll(ALEF_MAQSURA, YA)
    .replace(ZERO_WIDTH_JOINERS, "")
    .replace(APOSTROPHES, "")
    .replace(SEPARATORS, " ")
    .toLowerCase()
    .replace(SPACES, " ")
    .trim();
}

/** Normalized with the spaces removed: search ignores spaces. */
function compact(text: string): string {
  return normalizeForSearch(text).replaceAll(" ", "");
}

interface SearchEntry {
  dhikr: Dhikr;
  /** Every title and alias. */
  names: string[];
  /** The Arabic, every transliteration, and the translation in the language and in English. */
  others: string[];
}

function entryFor(dhikr: Dhikr, language: Language): SearchEntry {
  const { title, aliases, transliteration, translation } = dhikr;
  const names = [title.en, title.ar, title.ml, ...(aliases?.en ?? []), ...(aliases?.ar ?? []), ...(aliases?.ml ?? [])];
  const others = [dhikr.arabic, transliteration.en, transliteration.ml, translation[language], translation.en];
  return {
    dhikr,
    names: names.map(compact),
    others: others.filter((text) => text !== undefined).map(compact),
  };
}

/** The compacted fields of every dhikr, built once per catalog and language. */
const indexes = new WeakMap<Catalog, Map<Language, SearchEntry[]>>();

function indexFor(catalog: Catalog, language: Language): SearchEntry[] {
  let byLanguage = indexes.get(catalog);
  if (byLanguage === undefined) {
    byLanguage = new Map();
    indexes.set(catalog, byLanguage);
  }
  let index = byLanguage.get(language);
  if (index === undefined) {
    index = catalog.dhikrs.map((dhikr) => entryFor(dhikr, language));
    byLanguage.set(language, index);
  }
  return index;
}

/**
 * Searches the catalog (contracts/dhikr-catalog/v1/fixtures/dhikr_search.json). A dhikr matches
 * when the normalized query, spaces removed, is inside any title, alias, its Arabic, a
 * transliteration, or its translation in `language` or English. Dhikrs with a name that starts
 * with the query come first; otherwise catalog order. A blank query returns every dhikr.
 */
export function searchDhikrs(catalog: Catalog, query: string, language: Language): readonly Dhikr[] {
  const needle = compact(query);
  if (needle === "") return catalog.dhikrs;
  const prefixed: Dhikr[] = [];
  const contained: Dhikr[] = [];
  for (const { dhikr, names, others } of indexFor(catalog, language)) {
    if (names.some((name) => name.startsWith(needle))) prefixed.push(dhikr);
    else if ([...names, ...others].some((text) => text.includes(needle))) contained.push(dhikr);
  }
  return [...prefixed, ...contained];
}
