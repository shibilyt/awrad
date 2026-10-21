// Fails when a translation key exists in one language but not in another.
import { readFileSync } from "node:fs";

const languages = ["en", "ar", "ml"];
const keys = (value, prefix = "") =>
  Object.entries(value).flatMap(([key, child]) =>
    typeof child === "object" && child !== null ? keys(child, `${prefix}${key}.`) : [`${prefix}${key}`],
  );
const sets = Object.fromEntries(
  languages.map((language) => [
    language,
    new Set(keys(JSON.parse(readFileSync(`src/shared/i18n/locales/${language}.json`, "utf8")))),
  ]),
);
const all = new Set(languages.flatMap((language) => [...sets[language]]));
const problems = languages.flatMap((language) =>
  [...all].filter((key) => !sets[language].has(key)).map((key) => `${language} is missing "${key}"`),
);
for (const problem of problems) console.error(`translations: ${problem}`);
if (problems.length > 0) process.exit(1);
console.log(`translations: ${String(all.size)} keys present in ${languages.join(", ")}`);
