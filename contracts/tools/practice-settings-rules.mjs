// Reference implementations of the slice 3d rules (contracts/practice-settings/v1/README.md, places/v1/README.md).
// tools/check-practice-settings.mjs compares every fixture case with them, so a fixture can't drift from its rule.
// Platforms never import this file: each implements the rules itself and runs the fixtures.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import * as adhan from "adhan";

const root = fileURLToPath(new URL("..", import.meta.url));
const read = (path) => JSON.parse(readFileSync(join(root, path), "utf8"));

const DAY = 86_400_000;
const table = read("hijri-calendar/v1/umm-al-qura.json");
const months = [];
for (let year = table.first_year; year <= table.last_year; year += 1) {
  table.month_starts[String(year)].forEach((date, i) => months.push({ year, month: i + 1, start: Date.parse(date) }));
}
const tableEnd = Date.parse(table.end_exclusive);

/** The hijri_corrections_validity codes of a correction set, sorted (hijri-calendar/v1/README.md). */
export function hijriCorrectionErrors(corrections) {
  const errors = new Set();
  const seen = new Set();
  for (const c of corrections) {
    if (Math.abs(c.offset_days) > 2) errors.add("offset_out_of_range");
    if (c.year < table.first_year || c.year > table.last_year || c.month < 1 || c.month > 12) errors.add("month_out_of_range");
    const key = `${c.year}/${c.month}`;
    if (seen.has(key)) errors.add("duplicate_month");
    seen.add(key);
  }
  if (errors.size === 0 && !monthLengthsValid(corrections)) errors.add("month_length_invalid");
  return [...errors].sort();
}

function monthLengthsValid(corrections) {
  const offsets = new Map(corrections.map((c) => [`${c.year}/${c.month}`, c.offset_days]));
  let offset = 0;
  const starts = months.map((m) => {
    offset = offsets.get(`${m.year}/${m.month}`) ?? offset;
    return m.start + offset * DAY;
  });
  starts.push(tableEnd + offset * DAY);
  return starts.slice(1).every((start, i) => [29, 30].includes((start - starts[i]) / DAY));
}

const POLICY_MEMBERS = ["day_reset", "calculation_method", "madhab", "week_start", "hijri_corrections"];
const ENUMS = {
  day_reset: ["midnight", "maghrib"],
  calculation_method: read("practice-settings/v1/practice-settings.schema.json").$defs.calculation_method.enum,
  madhab: ["shafi", "hanafi"],
  week_start: ["saturday", "sunday", "monday"],
};

const isInt = (v) => Number.isInteger(v);
function correctionShapeValid(c) {
  if (typeof c !== "object" || c === null || Array.isArray(c)) return false;
  const keys = Object.keys(c).sort().join(",");
  if (keys !== "month,offset_days,year") return false;
  if (!isInt(c.year) || !isInt(c.month) || !isInt(c.offset_days)) return false;
  return c.year >= table.first_year && c.year <= table.last_year && c.month >= 1 && c.month <= 12 && Math.abs(c.offset_days) <= 2;
}

/** The {field, code} errors of a practice_policy document, sorted by field, then code. Empty when valid. */
export function policyErrors(document) {
  const errors = [];
  for (const key of Object.keys(document)) if (!POLICY_MEMBERS.includes(key)) errors.push({ field: `/${key}`, code: "not_allowed" });
  for (const key of POLICY_MEMBERS) {
    if (!(key in document)) errors.push({ field: `/${key}`, code: "required" });
    else if (key in ENUMS && !ENUMS[key].includes(document[key])) errors.push({ field: `/${key}`, code: "invalid" });
  }
  const corrections = document.hijri_corrections;
  if ("hijri_corrections" in document) {
    if (!Array.isArray(corrections)) {
      errors.push({ field: "/hijri_corrections", code: "invalid" });
    } else {
      const bad = corrections.map((c, i) => [c, i]).filter(([c]) => !correctionShapeValid(c));
      for (const [, i] of bad) errors.push({ field: `/hijri_corrections/${i}`, code: "invalid" });
      if (bad.length === 0) {
        const seen = new Set();
        corrections.forEach((c, i) => {
          const key = `${c.year}/${c.month}`;
          if (seen.has(key)) errors.push({ field: `/hijri_corrections/${i}`, code: "duplicate" });
          seen.add(key);
        });
        if (seen.size === corrections.length && !monthLengthsValid(corrections)) errors.push({ field: "/hijri_corrections", code: "range" });
      }
    }
  }
  return errors.sort((a, b) => (a.field === b.field ? (a.code < b.code ? -1 : 1) : a.field < b.field ? -1 : 1));
}

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const byMonth = (a, b) => a.year - b.year || a.month - b.month;

/**
 * Merge by setting (practice_policy_merge): every setting where mine differs from base keeps mine, the rest is
 * theirs; Hijri corrections merge month by month the same way. Merged corrections that aren't valid fall back to
 * theirs, with the notice hijri_corrections_replaced.
 */
export function mergePolicy(base, mine, theirs) {
  const merged = {};
  for (const key of ["day_reset", "calculation_method", "madhab", "week_start"]) merged[key] = mine[key] !== base[key] ? mine[key] : theirs[key];
  const map = (list) => new Map(list.map((c) => [`${c.year}/${c.month}`, c]));
  const [b, m, t] = [map(base.hijri_corrections), map(mine.hijri_corrections), map(theirs.hijri_corrections)];
  const result = new Map(t);
  for (const key of new Set([...b.keys(), ...m.keys()])) {
    if (same(m.get(key), b.get(key))) continue;
    if (m.has(key)) result.set(key, m.get(key));
    else result.delete(key);
  }
  let corrections = [...result.values()].sort(byMonth);
  let notice = null;
  if (hijriCorrectionErrors(corrections).length > 0) {
    corrections = [...theirs.hijri_corrections].sort(byMonth);
    notice = "hijri_corrections_replaced";
  }
  merged.hijri_corrections = corrections;
  const theirsSorted = { ...theirs, hijri_corrections: [...theirs.hijri_corrections].sort(byMonth) };
  return { document: merged, requeue: !same(merged, theirsSorted), notice };
}

/**
 * The phone's practice policy after signing in from the anonymous profile (practice_policy_first_sign_in). Into an
 * account profile already on the phone, that profile keeps its own policy. Otherwise, whatever the user chose for
 * their data: the account's policy if it has one, else this phone's, queued as a create only if the user chose it.
 */
export function firstSignIn({ event, local, account, existing_profile }) {
  if (event === "existing_profile") return { document: existing_profile.document, known_version: existing_profile.known_version, queued: null };
  if (account !== null) return { document: account.document, known_version: account.version, queued: null };
  if (local.chosen) return { document: local.document, known_version: 0, queued: { base_version: 0, document: local.document } };
  return { document: local.document, known_version: 0, queued: null };
}

const METHODS = {
  karachi: "Karachi",
  north_america: "NorthAmerica",
  muslim_world_league: "MuslimWorldLeague",
  egyptian: "Egyptian",
  umm_al_qura: "UmmAlQura",
  moonsighting_committee: "MoonsightingCommittee",
  dubai: "Dubai",
  kuwait: "Kuwait",
  qatar: "Qatar",
  singapore: "Singapore",
};

/** Maghrib on a local date at a place (maghrib_time), as adhan computes it, rounded to the minute; null without a sunset. */
export function maghrib({ date, latitude, longitude, calculation_method }) {
  const [y, m, d] = date.split("-").map(Number);
  const params = adhan.CalculationMethod[METHODS[calculation_method]]();
  const times = new adhan.PrayerTimes(new adhan.Coordinates(latitude, longitude), new Date(y, m - 1, d), params);
  const t = times.maghrib;
  return Number.isNaN(t?.getTime()) ? null : t.toISOString().replace(":00.000Z", "Z");
}

/**
 * Search key (city_search): NFKD; Latin combining accents (U+0300-U+036F), Arabic harakat (U+064B-U+065F, U+0670)
 * and tatweel removed; alef forms, alef maksura and ta marbuta folded; lowercased; every run of other characters
 * that aren't letters, marks or digits becomes one space; trimmed. Other scripts' marks (Malayalam vowel signs) stay.
 */
export function searchKey(text) {
  return text
    .normalize("NFKD")
    .replace(/[\u0300-\u036f\u064b-\u065f\u0670\u0640]/g, "")
    .replace(/[آأإٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/['’ʼ`]/g, "")
    .toLowerCase()
    .replace(/[^\p{L}\p{M}\p{N}]+/gu, " ")
    .trim();
}

/**
 * Bundled city search (city_search). A name matches the query exactly, by its start, or by the start of a later
 * word, in that order of strength. A city's tier is its strongest match: 0 the name exactly, 1 an alias exactly,
 * 2 the name's start, 3 an alias's start, 4 a word of the name, 5 a word of an alias. Lower tier first, then larger
 * population, then smaller ID; at most `limit`. A query whose key is empty finds nothing.
 */
export function searchCities(cities, query, limit = 20) {
  const q = searchKey(query);
  if (q === "") return [];
  const strength = (key) => (key === q ? 0 : key.startsWith(q) ? 1 : key.includes(` ${q}`) ? 2 : null);
  const hits = [];
  for (const city of cities) {
    let tier = null;
    [city.name, ...city.aliases].forEach((name, i) => {
      const s = strength(searchKey(name));
      if (s !== null) tier = Math.min(tier ?? 6, s * 2 + (i === 0 ? 0 : 1));
    });
    if (tier !== null) hits.push({ city, tier });
  }
  hits.sort((a, b) => a.tier - b.tier || b.city.population - a.city.population || a.city.id - b.city.id);
  return hits.slice(0, limit).map((h) => h.city.id);
}
