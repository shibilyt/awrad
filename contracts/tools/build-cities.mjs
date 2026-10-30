// Builds contracts/places/v1/cities.json, the bundled city list (places/v1/README.md), from a GeoNames dump.
// Usage: node tools/build-cities.mjs <dir>   where <dir> holds cities15000.txt and admin1CodesASCII.txt from
// https://download.geonames.org/export/dump/ (CC BY 4.0). The dump isn't committed; the output is.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

/** Minimum population: the default, and lower thresholds for regions (country, or country.admin1). */
export const THRESHOLDS = {
  default: 50_000,
  regions: {
    "IN.13": 15_000, // Kerala
    SA: 15_000,
    AE: 15_000,
    KW: 15_000,
    QA: 15_000,
    BH: 15_000,
    OM: 15_000,
  },
};
/** Sections of a city, and historical, abandoned or destroyed places. */
const SKIPPED_FEATURES = new Set(["PPLX", "PPLH", "PPLQ", "PPLW"]);
const ARABIC = /^[؀-ۿݐ-ݿ\s]+$/u;
const MALAYALAM = /^[ഀ-ൿ‌‍\s]+$/u;
/** Capitalised Latin names of at most three words: older and English names (Calicut), not nicknames. */
const LATIN_NAME = /^[A-Z][a-z]+([ -][A-Z]?[a-z]+){0,2}$/;

const root = fileURLToPath(new URL("..", import.meta.url));
const tsv = (path) => readFileSync(path, "utf8").split("\n").filter(Boolean).map((line) => line.split("\t"));

export function buildCities(dir) {
  const regions = new Map(tsv(join(dir, "admin1CodesASCII.txt")).map((r) => [r[0], r[2]]));
  const cities = [];
  for (const r of tsv(join(dir, "cities15000.txt"))) {
    const [id, name, ascii, alternates, lat, lon, , feature, country, , admin1] = r;
    const population = Number(r[14]);
    if (SKIPPED_FEATURES.has(feature)) continue;
    const min = THRESHOLDS.regions[`${country}.${admin1}`] ?? THRESHOLDS.regions[country] ?? THRESHOLDS.default;
    if (population < min) continue;
    const display = ascii || name;
    const aliases = (alternates ? alternates.split(",") : [])
      .filter((a) => ARABIC.test(a) || MALAYALAM.test(a) || LATIN_NAME.test(a))
      .concat(name !== display ? [name] : []);
    cities.push({
      id: Number(id),
      name: display,
      country,
      region: regions.get(`${country}.${admin1}`) ?? null,
      latitude: Number(Number(lat).toFixed(4)),
      longitude: Number(Number(lon).toFixed(4)),
      population,
      aliases: [...new Set(aliases.map((a) => a.trim()))].filter((a) => a !== "" && a !== display).sort(),
    });
  }
  cities.sort((a, b) => a.id - b.id);
  return cities;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [dir] = process.argv.slice(2);
  if (!dir) {
    console.error("usage: node tools/build-cities.mjs <geonames-dump-dir>");
    process.exit(2);
  }
  const cities = buildCities(dir);
  const header = {
    format: "awrad-cities/1",
    source: "GeoNames cities15000 (https://download.geonames.org/export/dump/), built by tools/build-cities.mjs",
    license: "CC BY 4.0",
    attribution: "City data © GeoNames (geonames.org), CC BY 4.0",
    thresholds: THRESHOLDS,
  };
  const body = JSON.stringify(header, null, 2).replace(/\n}$/, ',\n  "cities": [\n');
  const out = `${body}${cities.map((c) => `    ${JSON.stringify(c)}`).join(",\n")}\n  ]\n}\n`;
  writeFileSync(join(root, "places/v1/cities.json"), out);
  console.log(`places/v1/cities.json: ${cities.length} cities, ${Buffer.byteLength(out)} bytes`);
}
