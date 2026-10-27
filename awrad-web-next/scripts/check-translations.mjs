// Fails when a translation key exists in one language but not in another: the app's strings
// (src/shared/i18n/locales) and the dev component gallery's sample text (src/dev/gallery/locales).
import { readFileSync } from "node:fs";

const languages = ["en", "ar", "ml"];
const directories = ["src/shared/i18n/locales", "src/dev/gallery/locales"];
const keys = (value, prefix = "") =>
  Object.entries(value).flatMap(([key, child]) =>
    typeof child === "object" && child !== null ? keys(child, `${prefix}${key}.`) : [`${prefix}${key}`],
  );

let total = 0;
const problems = directories.flatMap((directory) => {
  const sets = Object.fromEntries(
    languages.map((language) => [
      language,
      new Set(keys(JSON.parse(readFileSync(`${directory}/${language}.json`, "utf8")))),
    ]),
  );
  const all = new Set(languages.flatMap((language) => [...sets[language]]));
  total += all.size;
  return languages.flatMap((language) =>
    [...all].filter((key) => !sets[language].has(key)).map((key) => `${directory}: ${language} is missing "${key}"`),
  );
});
for (const problem of problems) console.error(`translations: ${problem}`);
if (problems.length > 0) process.exit(1);
console.log(`translations: ${String(total)} keys present in ${languages.join(", ")}`);
