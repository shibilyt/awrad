// check:fonts: the served fonts are byte-identical to contracts/design-tokens/v1/fonts.
import { copyFileSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, test } from "vitest";
import { CONTRACTS_FONTS, SERVED_FONTS, parseSums, staleFonts } from "./check-fonts.mjs";

const sums = parseSums(readFileSync(join(CONTRACTS_FONTS, "SHA256SUMS"), "utf8"));
const font = "googlesansflexrounded_regular.ttf";
let dir = "";

function servedCopy() {
  dir = mkdtempSync(join(tmpdir(), "awrad-fonts-"));
  copyFileSync(join(CONTRACTS_FONTS, font), join(dir, font));
  return dir;
}

afterEach(() => {
  if (dir) rmSync(dir, { recursive: true, force: true });
  dir = "";
});

describe("check:fonts", () => {
  test("the committed fonts match contracts", () => {
    expect(readdirSync(SERVED_FONTS)).toContain(font);
    expect(staleFonts(SERVED_FONTS, sums)).toEqual([]);
  });

  test("passes an exact copy", () => {
    expect(staleFonts(servedCopy(), sums)).toEqual([]);
  });

  test("fails a modified copy", () => {
    const served = servedCopy();
    writeFileSync(join(served, font), Buffer.concat([readFileSync(join(served, font)), Buffer.from([0])]));
    expect(staleFonts(served, sums)).toEqual([`${font}: differs from the contracts copy`]);
  });

  test("fails a font contracts doesn't have", () => {
    const served = servedCopy();
    writeFileSync(join(served, "manrope_regular.ttf"), "");
    expect(staleFonts(served, sums)).toEqual([
      "manrope_regular.ttf: not in contracts/design-tokens/v1/fonts/SHA256SUMS",
    ]);
  });
});
