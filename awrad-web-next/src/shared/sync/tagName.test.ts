import { describe, expect, test } from "vitest";
import { caseFold, tagDisplayName } from "./tagName";

// Beyond the shared fixture: where Unicode case folding differs from upper-then-lower casing.
describe("caseFold", () => {
  test("keeps dotless ı, which lower-casing its upper case would turn into i", () => {
    expect(caseFold("ı")).toBe("ı");
  });

  test("folds Cherokee to its upper case, as CaseFolding.txt does", () => {
    expect(caseFold("ꭰ")).toBe("Ꭰ");
    expect(caseFold("ᏸ")).toBe("Ᏸ");
    expect(caseFold("Ꭰ")).toBe("Ꭰ");
  });

  test("capital sharp s folds to ss", () => {
    expect(caseFold("ẞ")).toBe("ss");
  });
});

test("the display name keeps a byte order mark, which isn't White_Space", () => {
  expect(tagDisplayName("﻿Morning ")).toBe("﻿Morning");
});
