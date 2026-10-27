// Validates the built-in dhikr catalog (dhikr-catalog/v1/catalog.json): schema, identity parity with
// progress-model/v1/builtin-dhikrs.json, collections, references and virtues, scripts and Qur'an ranges;
// prints the translation gaps.
// Usage: node tools/check-dhikr-catalog.mjs [catalog.json]   (default: dhikr-catalog/v1/catalog.json)
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { newAjv } from "./check-fixtures.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const catalogPath = process.argv[2] ? resolve(process.argv[2]) : join(root, "dhikr-catalog/v1/catalog.json");
const catalog = JSON.parse(readFileSync(catalogPath, "utf8"));
const registry = JSON.parse(readFileSync(join(root, "progress-model/v1/builtin-dhikrs.json"), "utf8"));
const problems = [];

// Schema.
const check = newAjv().getSchema("urn:awrad:dhikr-catalog:1");
if (!check(catalog)) {
  for (const e of check.errors) problems.push(`schema: ${e.instancePath || "/"} ${e.message}`);
  report();
}

// Unique keys and ids.
const byKey = new Map();
const ids = new Set();
for (const d of catalog.dhikrs) {
  if (byKey.has(d.key)) problems.push(`duplicate dhikr key "${d.key}"`);
  if (ids.has(d.id)) problems.push(`duplicate dhikr id ${d.id} (${d.key})`);
  byKey.set(d.key, d);
  ids.add(d.id);
}

// Identity parity: exactly the registry's key/id pairs, no more and no fewer.
const registered = new Map(registry.dhikrs.map((r) => [r.catalog_key, r.id]));
for (const [key, id] of registered) {
  const d = byKey.get(key);
  if (!d) problems.push(`registry dhikr "${key}" is missing from the catalog`);
  else if (d.id !== id) problems.push(`"${key}" has id ${d.id}, registry says ${id}`);
}
for (const key of byKey.keys())
  if (!registered.has(key)) problems.push(`"${key}" isn't in progress-model/v1/builtin-dhikrs.json`);

// Collections: unique keys, references resolve, no duplicates within one, every dhikr listed somewhere.
const collected = new Set();
const collectionKeys = new Set();
for (const c of catalog.collections) {
  if (collectionKeys.has(c.key)) problems.push(`duplicate collection key "${c.key}"`);
  collectionKeys.add(c.key);
  const seen = new Set();
  for (const key of c.dhikrs) {
    if (!byKey.has(key)) problems.push(`collection "${c.key}" names unknown dhikr "${key}"`);
    if (seen.has(key)) problems.push(`collection "${c.key}" lists "${key}" twice`);
    seen.add(key);
    collected.add(key);
  }
}
for (const key of byKey.keys())
  if (!collected.has(key)) problems.push(`"${key}" isn't in any collection`);

// References: ids unique within a dhikr, every virtue's references resolve, quran-kind dhikrs cite the Qur'an.
for (const d of catalog.dhikrs) {
  const refIds = new Set();
  for (const r of d.references) {
    if (refIds.has(r.id)) problems.push(`${d.key} has two references with id "${r.id}"`);
    refIds.add(r.id);
  }
  d.virtues.forEach((v, i) => {
    for (const id of v.references)
      if (!refIds.has(id)) problems.push(`${d.key}.virtues[${i}] names unknown reference "${id}"`);
  });
  if (d.kind === "quran" && !d.references.some((r) => r.type === "quran"))
    problems.push(`${d.key} is kind quran but has no quran reference`);
}

// Scripts: Arabic fields are Arabic, and the recited text has no Latin letters, ayah numbers or separators;
// each transliteration is in its language's script.
const ARABIC = /\p{Script=Arabic}/u;
const arabicField = (where, value, strict) => {
  if (value === undefined) return;
  if (!ARABIC.test(value)) problems.push(`${where} has no Arabic script`);
  if (strict && /[A-Za-z]/.test(value)) problems.push(`${where} contains Latin letters`);
  if (strict && /\(\s*[\d٠-٩]+\s*\)|❁/.test(value)) problems.push(`${where} contains an ayah number or separator`);
};
for (const d of catalog.dhikrs) {
  arabicField(`${d.key}.arabic`, d.arabic, true);
  arabicField(`${d.key}.title.ar`, d.title.ar, false);
  arabicField(`${d.key}.translation.ar`, d.translation.ar, false);
  d.virtues.forEach((v, i) => arabicField(`${d.key}.virtues[${i}].text.ar`, v.text.ar, false));
  if (!/[A-Za-z]/.test(d.transliteration.en) || ARABIC.test(d.transliteration.en))
    problems.push(`${d.key}.transliteration.en isn't Latin script`);
  if (d.transliteration.ml !== undefined && !/\p{Script=Malayalam}/u.test(d.transliteration.ml))
    problems.push(`${d.key}.transliteration.ml isn't Malayalam script`);
  // Aliases: in their language's script, and not a repeat of what search already sees (title, transliteration).
  const SCRIPT = { en: /[A-Za-z]/, ar: ARABIC, ml: /\p{Script=Malayalam}/u };
  for (const [lang, list] of Object.entries(d.aliases ?? {})) {
    const shown = [d.title[lang], d.transliteration[lang]].filter(Boolean).map((t) => t.toLowerCase());
    for (const alias of list) {
      if (!SCRIPT[lang].test(alias)) problems.push(`${d.key}.aliases.${lang} "${alias}" isn't in ${lang} script`);
      if (shown.includes(alias.toLowerCase()))
        problems.push(`${d.key}.aliases.${lang} "${alias}" repeats the title or transliteration`);
    }
  }
}
for (const c of catalog.collections) arabicField(`collection ${c.key}.title.ar`, c.title.ar, false);

// Qur'an references fall inside the surah (Hafs ayah counts, 6236 in total).
const AYAHS = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135, 112, 78, 118, 64, 77,
  227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55,
  78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36,
  25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
];
if (AYAHS.length !== 114 || AYAHS.reduce((a, b) => a + b) !== 6236) problems.push("internal: ayah table is wrong");
for (const d of catalog.dhikrs)
  for (const q of d.references.filter((r) => r.type === "quran")) {
    const where = `${d.key} reference "${q.id}"`;
    if (q.ayahStart > q.ayahEnd) problems.push(`${where} starts after it ends`);
    if (q.ayahEnd > AYAHS[q.surah - 1])
      problems.push(`${where} ends at ${q.ayahEnd}, surah ${q.surah} has ${AYAHS[q.surah - 1]} ayahs`);
  }

report();

function report() {
  if (problems.length) {
    for (const p of problems) console.error(`${catalogPath}: ${p}`);
    process.exit(1);
  }
  // Translation gaps: visible on every run, never a failure (apps fall back to en).
  const missing = (items, lang) => items.filter((t) => !t[lang]).length;
  const translations = catalog.dhikrs.map((d) => d.translation);
  const virtues = catalog.dhikrs.flatMap((d) => d.virtues.map((v) => v.text));
  const transliterations = catalog.dhikrs.map((d) => d.transliteration);
  console.log(
    `dhikr catalog: ${catalog.dhikrs.length} dhikrs and ${catalog.collections.length} collections valid; ` +
      `key/id parity with builtin-dhikrs.json holds`,
  );
  console.log(
    `  missing (apps fall back to en): translation ar ${missing(translations, "ar")}, ml ${missing(translations, "ml")} ` +
      `of ${translations.length}; virtue ar ${missing(virtues, "ar")}, ml ${missing(virtues, "ml")} of ${virtues.length}; ` +
      `ml transliteration ${missing(transliterations, "ml")} of ${transliterations.length}`,
  );
}
