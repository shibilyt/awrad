// check:translations: every key in every language, plurals by each language's own forms.
import { describe, expect, test } from "vitest";
import { translationProblems } from "./check-translations.mjs";

const COUNT = {
  en: { n_one: "{{count}} dhikr", n_other: "{{count}} dhikrs" },
  ar: { n_zero: "0", n_one: "1", n_two: "2", n_few: "3", n_many: "11", n_other: "100" },
  ml: { n_one: "1", n_other: "2" },
};

describe("check:translations", () => {
  test("a plural is one key, with each language's own forms", () => {
    expect(translationProblems(COUNT)).toEqual({ problems: [], total: 1 });
  });

  test("fails on a missing key and on missing or unused plural forms", () => {
    const { problems } = translationProblems({
      en: { a: "A", n_one: "1", n_other: "2" },
      ar: { n_one: "1", n_other: "2" },
      ml: { a: "A", n_one: "1", n_two: "2", n_other: "3" },
    });
    expect(problems).toEqual([
      'ar is missing "a"',
      'ar "n" lacks plural forms zero, two, few, many',
      'ml "n" has plural forms it never uses: two',
    ]);
  });
});
