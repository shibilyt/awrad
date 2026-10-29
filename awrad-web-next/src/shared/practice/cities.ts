/**
 * The bundled city list (contracts/places/v1): cities users can pick as their location, read
 * straight from `cities.json` at build time. It's 2.6 MB, so it's a chunk of its own, loaded only
 * when city search opens (`loadCities`), and imported as text so the type checker never reads it.
 */

export interface City {
  /** The GeoNames ID. */
  id: number;
  /** GeoNames' ASCII name, shown in every language. */
  name: string;
  /** ISO 3166-1 alpha-2; shown by `Intl.DisplayNames` in the UI language. */
  country: string;
  region: string | null;
  latitude: number;
  longitude: number;
  population: number;
  /** Names search matches but never shows (other scripts, older English names, the accented name). */
  aliases: readonly string[];
}

export interface CityList {
  /** The licence line to show with the list (GeoNames, CC BY 4.0). */
  attribution: string;
  cities: readonly City[];
}

let loading: Promise<CityList> | null = null;

/** The city list, loaded once. */
export function loadCities(): Promise<CityList> {
  loading ??= import("../../../../contracts/places/v1/cities.json?raw").then(({ default: text }) => {
    const list = JSON.parse(text) as { format?: unknown } & CityList;
    if (list.format !== "awrad-cities/1") throw new Error("cities.json has an unknown format");
    return { attribution: list.attribution, cities: list.cities };
  });
  loading.catch(() => {
    loading = null;
  });
  return loading;
}

/**
 * The search key of a query or a name (city_search): NFKD; Latin accents, Arabic harakat and
 * tatweel removed; Arabic alef forms, alef maksura and ta marbuta folded; apostrophes removed;
 * lowercased; every run of characters that aren't letters, marks or digits one space; trimmed.
 */
export function searchKey(text: string): string {
  return text
    .normalize("NFKD")
    .replace(/[\u0300-\u036f\u064b-\u065f\u0670\u0640]/g, "")
    .replace(/[آأإٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/['\u2019\u02bc`]/g, "")
    .toLowerCase()
    .replace(/[^\p{L}\p{M}\p{N}]+/gu, " ")
    .trim();
}

/** Each city's search keys, its name's first: worked out once per list, not per keystroke. */
const indexes = new WeakMap<readonly City[], readonly { city: City; keys: readonly string[] }[]>();

function indexOf(cities: readonly City[]) {
  let index = indexes.get(cities);
  if (index === undefined) {
    index = cities.map((city) => ({ city, keys: [city.name, ...city.aliases].map(searchKey) }));
    indexes.set(cities, index);
  }
  return index;
}

/** 0 exactly, 1 by its start, 2 by a later word's start, or `null`. */
function strength(key: string, query: string): number | null {
  if (key === query) return 0;
  if (key.startsWith(query)) return 1;
  return key.includes(` ${query}`) ? 2 : null;
}

/**
 * city_search: the cities a query finds, best first, at most `limit`. A city's tier is its best
 * match: the name exactly, an alias exactly, the name's start, an alias's start, a later word of
 * the name, a later word of an alias. Then larger cities first, then by ID.
 */
export function searchCities(cities: readonly City[], query: string, limit = 20): City[] {
  const q = searchKey(query);
  if (q === "") return [];
  const hits: { city: City; tier: number }[] = [];
  for (const { city, keys } of indexOf(cities)) {
    let tier = Infinity;
    for (const [i, key] of keys.entries()) {
      const s = strength(key, q);
      if (s !== null) tier = Math.min(tier, s * 2 + (i === 0 ? 0 : 1));
    }
    if (tier !== Infinity) hits.push({ city, tier });
  }
  hits.sort((a, b) => a.tier - b.tier || b.city.population - a.city.population || a.city.id - b.city.id);
  return hits.slice(0, limit).map((hit) => hit.city);
}
