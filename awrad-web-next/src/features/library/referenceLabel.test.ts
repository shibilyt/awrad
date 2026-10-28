import i18next from "i18next";
import { describe, expect, test } from "vitest";
import type { Reference } from "@/shared/dhikr-catalog";
import { referenceLabel } from "./referenceLabel";

const t = i18next.t.bind(i18next);

describe("reference labels", () => {
  test("Qur'an: surah and ayah, or a range with an en dash", () => {
    const one: Reference = { id: "q", type: "quran", surah: 71, ayah_start: 10, ayah_end: 10 };
    const range: Reference = { id: "q", type: "quran", surah: 112, ayah_start: 1, ayah_end: 4 };
    expect(referenceLabel(one, t, "en")).toBe("Qur'an 71:10");
    expect(referenceLabel(range, t, "en")).toBe("Qur'an 112:1–4");
  });

  test("in Arabic the numbers are isolated left to right, so they keep their order", async () => {
    await i18next.changeLanguage("ar");
    const range: Reference = { id: "q", type: "quran", surah: 112, ayah_start: 1, ayah_end: 4 };
    expect(referenceLabel(range, t, "ar")).toBe("القرآن \u2066112:1–4\u2069");
  });

  test("hadith, with its grade when there is one", () => {
    expect(referenceLabel({ id: "h", type: "hadith", collection: "Sahih Muslim", number: "408" }, t, "en")).toBe(
      "Sahih Muslim 408",
    );
    expect(
      referenceLabel(
        { id: "h", type: "hadith", collection: "Sunan Abi Dawud", number: "1518", grade: "Da'if (al-Albani)" },
        t,
        "en",
      ),
    ).toBe("Sunan Abi Dawud 1518 · Da'if (al-Albani)");
  });

  test("book, shaykh and other", () => {
    expect(
      referenceLabel(
        { id: "b", type: "book", title: "Al-Adhkar", author: "An-Nawawi", volume: "1", page: "42" },
        t,
        "en",
      ),
    ).toBe("Al-Adhkar, An-Nawawi, vol. 1, p. 42");
    expect(referenceLabel({ id: "b", type: "book", title: "Al-Adhkar" }, t, "en")).toBe("Al-Adhkar");
    expect(referenceLabel({ id: "s", type: "shaykh", name: "Shaykh A", note: "oral" }, t, "en")).toBe(
      "Shaykh A (oral)",
    );
    expect(referenceLabel({ id: "o", type: "other", text: "Local tradition" }, t, "en")).toBe("Local tradition");
  });
});
