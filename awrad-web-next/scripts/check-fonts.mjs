// Fails when a font in public/fonts isn't byte-identical to the shared copy in
// contracts/design-tokens/v1/fonts: every served file must be listed in that folder's
// SHA256SUMS with the same checksum, and every font theme.css loads must be served.
// To update, copy the file from contracts.
import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
export const CONTRACTS_FONTS = join(ROOT, "../contracts/design-tokens/v1/fonts");
export const SERVED_FONTS = join(ROOT, "public/fonts");
const THEME = join(ROOT, "src/shared/ui/theme.css");

/** `SHA256SUMS` text (`<hex>  <file>` per line) as a Map from file name to checksum. */
export function parseSums(text) {
  const sums = new Map();
  for (const line of text.split("\n")) {
    const match = /^([0-9a-f]{64}) [ *](.+)$/.exec(line.trim());
    if (match?.[1] && match[2]) sums.set(match[2], match[1]);
  }
  return sums;
}

/** Every served font that is unknown to, or differs from, the contracts copy. */
export function staleFonts(servedDir, sums) {
  const problems = [];
  for (const file of readdirSync(servedDir).sort()) {
    const expected = sums.get(file);
    if (expected === undefined) {
      problems.push(`${file}: not in contracts/design-tokens/v1/fonts/SHA256SUMS`);
      continue;
    }
    const actual = createHash("sha256")
      .update(readFileSync(join(servedDir, file)))
      .digest("hex");
    if (actual !== expected) problems.push(`${file}: differs from the contracts copy`);
  }
  return problems;
}

function main() {
  const sums = parseSums(readFileSync(join(CONTRACTS_FONTS, "SHA256SUMS"), "utf8"));
  const problems = staleFonts(SERVED_FONTS, sums);
  const served = new Set(readdirSync(SERVED_FONTS));
  for (const [, file] of readFileSync(THEME, "utf8").matchAll(/url\("\/fonts\/([^"]+)"\)/g)) {
    if (file && !served.has(file)) problems.push(`${file}: loaded by src/shared/ui/theme.css but not served`);
  }
  if (problems.length > 0) {
    console.error(problems.map((problem) => `public/fonts/${problem}`).join("\n"));
    console.error("Copy the font from contracts/design-tokens/v1/fonts/ into public/fonts/.");
    process.exit(1);
  }
  console.log(`fonts: ${String(readdirSync(SERVED_FONTS).length)} served fonts match contracts`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
