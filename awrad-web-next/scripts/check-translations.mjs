// Fails when a translation key exists in one language but not in another: the app's strings
// (src/shared/i18n/locales) and the dev component gallery's sample text (src/dev/gallery/locales).
//
// Plurals are i18next keys with a CLDR category suffix (`count_one`, `count_other`). Languages
// need different forms (Arabic has six), so a plural counts as one key, `count`, and each
// language must have exactly the forms its plural rules use (Intl.PluralRules).
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const LANGUAGES = ["en", "ar", "ml"];
const DIRECTORIES = ["src/shared/i18n/locales", "src/dev/gallery/locales"];
const PLURAL = /^(.+)_(zero|one|two|few|many|other)$/;

const leafKeys = (value, prefix = "") =>
  Object.entries(value).flatMap(([key, child]) =>
    typeof child === "object" && child !== null ? leafKeys(child, `${prefix}${key}.`) : [`${prefix}${key}`],
  );

/** A language's keys with plurals folded into their base key, and each plural's forms. */
export function foldPlurals(keys) {
  const plain = new Set();
  const plurals = new Map();
  for (const key of keys) {
    const match = PLURAL.exec(key);
    if (match === null) {
      plain.add(key);
      continue;
    }
    const [, base, form] = match;
    plain.add(base);
    plurals.set(base, [...(plurals.get(base) ?? []), form]);
  }
  return { keys: plain, plurals };
}

/** Problems with `byLanguage` (language → parsed JSON): missing keys and wrong plural forms. */
export function translationProblems(byLanguage, label = "") {
  const folded = Object.fromEntries(
    Object.entries(byLanguage).map(([language, json]) => [language, foldPlurals(leafKeys(json))]),
  );
  const all = new Set(Object.values(folded).flatMap(({ keys }) => [...keys]));
  const problems = [];
  for (const [language, { keys, plurals }] of Object.entries(folded)) {
    for (const key of all) if (!keys.has(key)) problems.push(`${label}${language} is missing "${key}"`);
    const needed = new Intl.PluralRules(language).resolvedOptions().pluralCategories;
    for (const [base, forms] of plurals) {
      const missing = needed.filter((form) => !forms.includes(form));
      const extra = forms.filter((form) => !needed.includes(form));
      if (missing.length > 0) problems.push(`${label}${language} "${base}" lacks plural forms ${missing.join(", ")}`);
      if (extra.length > 0)
        problems.push(`${label}${language} "${base}" has plural forms it never uses: ${extra.join(", ")}`);
    }
  }
  return { problems, total: all.size };
}

function main() {
  let total = 0;
  const problems = DIRECTORIES.flatMap((directory) => {
    const byLanguage = Object.fromEntries(
      LANGUAGES.map((language) => [language, JSON.parse(readFileSync(`${directory}/${language}.json`, "utf8"))]),
    );
    const result = translationProblems(byLanguage, `${directory}: `);
    total += result.total;
    return result.problems;
  });
  for (const problem of problems) console.error(`translations: ${problem}`);
  if (problems.length > 0) process.exit(1);
  console.log(`translations: ${String(total)} keys present in ${LANGUAGES.join(", ")}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
