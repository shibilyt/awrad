// Generates src/shared/dhikr-catalog/catalog.gen.ts from the shared dhikr catalog
// (contracts/dhikr-catalog/v1/catalog.json): the same data, typed as `Catalog`
// (src/shared/dhikr-catalog/types.ts). The app loads it lazily, in a chunk of its own.
//
// The generator knows every key of the catalog's shape (dhikr-catalog.schema.json). A key
// or value it doesn't know, or a missing required key, fails, so a field added to the
// contract can't silently miss the web's types. The output goes through the project's
// Prettier config, so it passes `format:check` as is.
//
//   node scripts/generate-catalog.mjs           write the file (npm run catalog)
//   node scripts/generate-catalog.mjs --check   fail when the committed file is stale (npm run validate)
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { format, resolveConfig } from "prettier";

const HERE = dirname(fileURLToPath(import.meta.url));
export const SOURCE = join(HERE, "../../contracts/dhikr-catalog/v1/catalog.json");
export const TARGET = join(HERE, "../src/shared/dhikr-catalog/catalog.gen.ts");

const LANGUAGES = ["en", "ar", "ml"];

/** Allowed keys and required keys of each object in the catalog, by shape. */
const SHAPES = {
  catalog: { keys: ["version", "contentRevision", "dhikrs", "collections", "tags"], required: "all" },
  dhikr: {
    keys: [
      "id",
      "key",
      "kind",
      "arabic",
      "title",
      "transliteration",
      "aliases",
      "tags",
      "translation",
      "audio",
      "references",
      "virtues",
    ],
    required: [
      "id",
      "key",
      "kind",
      "arabic",
      "title",
      "transliteration",
      "translation",
      "audio",
      "references",
      "virtues",
    ],
  },
  fullText: { keys: LANGUAGES, required: "all" },
  localText: { keys: LANGUAGES, required: ["en"] },
  transliteration: { keys: ["en", "ml"], required: ["en"] },
  aliases: { keys: LANGUAGES, required: [] },
  audio: {
    keys: ["url", "reciter", "style", "repetitions", "durationMs", "byteSize", "mimeType", "sha256", "attribution"],
    required: ["url", "style", "repetitions"],
  },
  reciter: { keys: ["name"], required: "all" },
  quran: { keys: ["id", "type", "surah", "ayahStart", "ayahEnd"], required: "all" },
  hadith: { keys: ["id", "type", "collection", "number", "narrator", "grade"], required: ["id", "type", "collection"] },
  book: { keys: ["id", "type", "title", "author", "volume", "page"], required: ["id", "type", "title"] },
  shaykh: { keys: ["id", "type", "name", "note"], required: ["id", "type", "name"] },
  other: { keys: ["id", "type", "text", "url"], required: ["id", "type", "text"] },
  virtue: { keys: ["text", "references"], required: "all" },
  collection: { keys: ["key", "title", "dhikrs"], required: "all" },
  tag: { keys: ["key", "title"], required: "all" },
};

const KINDS = ["quran", "dhikr", "dua", "salawat", "name_of_allah"];
const AUDIO_STYLES = ["recitation", "melodic", "teaching"];
const REFERENCE_TYPES = ["quran", "hadith", "book", "shaykh", "other"];

function fail(path, message) {
  throw new Error(`catalog.json ${path}: ${message}; teach scripts/generate-catalog.mjs and types.ts about it first`);
}

function checkObject(path, value, shape) {
  if (typeof value !== "object" || value === null || Array.isArray(value)) fail(path, "expected an object");
  const { keys, required } = SHAPES[shape];
  for (const key of Object.keys(value)) if (!keys.includes(key)) fail(path, `unknown key "${key}"`);
  for (const key of required === "all" ? keys : required) if (!(key in value)) fail(path, `missing "${key}"`);
}

function checkEnum(path, value, allowed) {
  if (!allowed.includes(value)) fail(path, `unknown value ${JSON.stringify(value)}`);
}

function checkDhikr(path, dhikr) {
  checkObject(path, dhikr, "dhikr");
  checkEnum(`${path}.kind`, dhikr.kind, KINDS);
  checkObject(`${path}.title`, dhikr.title, "fullText");
  checkObject(`${path}.transliteration`, dhikr.transliteration, "transliteration");
  checkObject(`${path}.translation`, dhikr.translation, "localText");
  if (dhikr.aliases !== undefined) checkObject(`${path}.aliases`, dhikr.aliases, "aliases");
  if (dhikr.audio !== null) {
    checkObject(`${path}.audio`, dhikr.audio, "audio");
    checkEnum(`${path}.audio.style`, dhikr.audio.style, AUDIO_STYLES);
    if (dhikr.audio.reciter !== undefined) {
      checkObject(`${path}.audio.reciter`, dhikr.audio.reciter, "reciter");
      checkObject(`${path}.audio.reciter.name`, dhikr.audio.reciter.name, "localText");
    }
  }
  dhikr.references.forEach((reference, index) => {
    checkEnum(`${path}.references[${String(index)}].type`, reference.type, REFERENCE_TYPES);
    checkObject(`${path}.references[${String(index)}]`, reference, reference.type);
  });
  dhikr.virtues.forEach((virtue, index) => {
    checkObject(`${path}.virtues[${String(index)}]`, virtue, "virtue");
    checkObject(`${path}.virtues[${String(index)}].text`, virtue.text, "localText");
  });
}

/** Throws when the catalog has a key, kind, style or reference type the web doesn't know, or misses a required key. */
export function checkCatalog(catalog) {
  checkObject("", catalog, "catalog");
  if (catalog.version !== 1) fail("version", `unknown version ${JSON.stringify(catalog.version)}`);
  catalog.dhikrs.forEach((dhikr, index) => {
    checkDhikr(`dhikrs[${String(index)}] (${String(dhikr.key)})`, dhikr);
  });
  catalog.collections.forEach((collection, index) => {
    const path = `collections[${String(index)}]`;
    checkObject(path, collection, "collection");
    checkObject(`${path}.title`, collection.title, "fullText");
  });
  catalog.tags.forEach((tag, index) => {
    const path = `tags[${String(index)}]`;
    checkObject(path, tag, "tag");
    checkObject(`${path}.title`, tag.title, "fullText");
  });
  return catalog;
}

export function readCatalog() {
  return JSON.parse(readFileSync(SOURCE, "utf8"));
}

/** The formatted TypeScript for a parsed catalog.json. */
export async function renderCatalogTs(catalog) {
  const source = [
    "// Generated by scripts/generate-catalog.mjs from contracts/dhikr-catalog/v1/catalog.json.",
    "// Don't edit: run `npm run catalog`. `npm run validate` fails when this file is stale.",
    "// Only load.ts imports it, lazily, so the catalog is a chunk of its own and not in the first page.",
    'import type { Catalog } from "./types";',
    "",
    `export const catalog: Catalog = ${JSON.stringify(checkCatalog(catalog))};`,
    "",
  ].join("\n");
  const options = (await resolveConfig(TARGET)) ?? {};
  return format(source, { ...options, filepath: TARGET });
}

async function main() {
  const ts = await renderCatalogTs(readCatalog());
  if (process.argv.includes("--check")) {
    let committed = "";
    try {
      committed = readFileSync(TARGET, "utf8");
    } catch {
      // A missing file is stale too.
    }
    if (committed !== ts) {
      console.error("src/shared/dhikr-catalog/catalog.gen.ts is stale or edited by hand. Run: npm run catalog");
      process.exit(1);
    }
    console.log("catalog: up to date with contracts/dhikr-catalog/v1/catalog.json");
    return;
  }
  writeFileSync(TARGET, ts);
  console.log("wrote src/shared/dhikr-catalog/catalog.gen.ts");
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
