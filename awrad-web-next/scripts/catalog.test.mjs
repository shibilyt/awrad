// The catalog pipeline: contracts/dhikr-catalog/v1/catalog.json → catalog.gen.ts.
import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { TARGET, checkCatalog, readCatalog, renderCatalogTs } from "./generate-catalog.mjs";

const source = readCatalog();

/** catalog.json with a change. */
function withChange(change) {
  const json = structuredClone(source);
  change(json);
  return json;
}

describe("catalog.gen.ts", () => {
  test("is the committed file", async () => {
    expect(readFileSync(TARGET, "utf8")).toBe(await renderCatalogTs(source));
  });

  test("fails on a key the web doesn't know, anywhere in the catalog", () => {
    expect(() => checkCatalog(withChange((json) => (json.featured = [])))).toThrow(/unknown key "featured"/);
    expect(() => checkCatalog(withChange((json) => (json.dhikrs[0].occasion = "morning")))).toThrow(
      /dhikrs\[0\] \(surah-ikhlas\): unknown key "occasion"/,
    );
    expect(() => checkCatalog(withChange((json) => (json.dhikrs[0].audio.loop = true)))).toThrow(/unknown key "loop"/);
    expect(() => checkCatalog(withChange((json) => (json.dhikrs[0].references[0].juz = 30)))).toThrow(
      /unknown key "juz"/,
    );
    expect(() => checkCatalog(withChange((json) => (json.collections[0].icon = "sun")))).toThrow(/unknown key "icon"/);
    expect(() => checkCatalog(withChange((json) => (json.dhikrs[0].title.ur = "سورہ")))).toThrow(/unknown key "ur"/);
  });

  test("fails on an unknown kind, reference type or version, and on a missing required key", () => {
    expect(() => checkCatalog(withChange((json) => (json.dhikrs[0].kind = "hadith")))).toThrow(
      /unknown value "hadith"/,
    );
    expect(() => checkCatalog(withChange((json) => (json.dhikrs[0].references[0].type = "tafsir")))).toThrow(
      /unknown value "tafsir"/,
    );
    expect(() => checkCatalog(withChange((json) => (json.version = 2)))).toThrow(/unknown version 2/);
    expect(() => checkCatalog(withChange((json) => delete json.dhikrs[0].arabic))).toThrow(/missing "arabic"/);
  });
});
