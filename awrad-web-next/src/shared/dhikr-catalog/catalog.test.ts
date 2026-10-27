import { describe, expect, test } from "vitest";
import { catalog } from "./catalog.gen";
import { collectionDhikrs, findCollection, findDhikr, findTag, loadCatalog } from "./load";
import { localized, transliterationFor } from "./localize";
import type { Dhikr } from "./types";

function dhikr(key: string): Dhikr {
  const found = findDhikr(catalog, key);
  if (found === undefined) throw new Error(`no dhikr ${key}`);
  return found;
}

describe("the generated catalog", () => {
  test("has the contract's 113 dhikrs and 5 collections, every collection's keys resolving", () => {
    expect(catalog.version).toBe(1);
    expect(catalog.dhikrs).toHaveLength(113);
    expect(catalog.collections.map((collection) => collection.key)).toEqual([
      "daily-essentials",
      "dhikrs",
      "swalaths",
      "ramadan",
      "asma-ul-husna",
    ]);
    for (const collection of catalog.collections) {
      expect(collectionDhikrs(catalog, collection)).toHaveLength(collection.dhikrs.length);
    }
    expect(findCollection(catalog, "asma-ul-husna")?.dhikrs).toHaveLength(100);
    expect(findTag(catalog, "debt")?.title.en).toBe("Debt");
  });

  test("loads lazily, as the same data", async () => {
    await expect(loadCatalog()).resolves.toBe(catalog);
  });

  test("finds nothing for an unknown key", () => {
    expect(findDhikr(catalog, "not-a-dhikr")).toBeUndefined();
    expect(findCollection(catalog, "not-a-collection")).toBeUndefined();
  });
});

describe("localized display", () => {
  test("picks the language's text and falls back to English when it's missing", () => {
    const nariyya = dhikr("swalath-al-nariyya");
    expect(localized(nariyya.translation, "ml")).toBe(nariyya.translation.ml);
    const ikhlas = dhikr("surah-ikhlas");
    expect(ikhlas.translation.ar).toBeUndefined();
    expect(localized(ikhlas.translation, "ar")).toBe(ikhlas.translation.en);
    expect(localized(ikhlas.translation, "ml")).toBe(ikhlas.translation.en);
  });

  test("Arabic shows no transliteration; Malayalam falls back to the English one", () => {
    const tahleel = dhikr("tahleel");
    expect(transliterationFor(tahleel, "ar")).toBeNull();
    expect(transliterationFor(tahleel, "en")).toBe(tahleel.transliteration.en);
    expect(transliterationFor(tahleel, "ml")).toBe(tahleel.transliteration.ml ?? tahleel.transliteration.en);
    expect(transliterationFor({ ...tahleel, transliteration: { en: "Latin", ml: "മലയാളം" } }, "ml")).toBe("മലയാളം");
  });
});
