// Fails when a colour is written anywhere except src/shared/ui/colors.gen.css, which is
// generated from contracts/design-tokens/v1/colors.json. Screens name roles instead
// (bg-surface, text-accent, …). Rejects hex colours, CSS colour functions and
// Tailwind's default palette classes (text-white, bg-red-500, …), which no longer exist.
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const ALLOWED = new Set(["src/shared/ui/colors.gen.css", "src/shared/api/schema.gen.ts", "src/routeTree.gen.ts"]);
const EXTENSIONS = /\.(?:css|ts|tsx|html)$/;

const PALETTE =
  "slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|black|white";
const UTILITIES =
  "bg|text|border(?:-[xytrblse])?|ring|ring-offset|outline|divide|fill|stroke|decoration|placeholder|caret|accent|shadow|inset-shadow|inset-ring|drop-shadow|text-shadow|from|via|to";
const RULES = [
  { name: "hex colour", pattern: /(?<![\w&])#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})(?![\w-])/g },
  { name: "colour function", pattern: /\b(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch|light-dark|color)\(/g },
  {
    name: "Tailwind palette class",
    pattern: new RegExp(`(?<![\\w-])(?:${UTILITIES})-(?:${PALETTE})(?:-\\d{2,3})?(?![\\w-])`, "g"),
  },
];

function* files(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) yield* files(path);
    else if (EXTENSIONS.test(entry.name)) yield path;
  }
}

/** Every raw colour in a file's text, as `line: rule "match"`. */
export function rawColors(text) {
  const found = [];
  text.split("\n").forEach((line, index) => {
    for (const { name, pattern } of RULES) {
      for (const match of line.matchAll(pattern)) found.push(`${String(index + 1)}: ${name} "${match[0]}"`);
    }
  });
  return found;
}

function main() {
  const problems = [];
  for (const path of [...files(join(ROOT, "src")), join(ROOT, "index.html")]) {
    const name = relative(ROOT, path);
    if (ALLOWED.has(name)) continue;
    for (const problem of rawColors(readFileSync(path, "utf8"))) problems.push(`${name}:${problem}`);
  }
  if (problems.length > 0) {
    console.error(problems.join("\n"));
    console.error("Use a colour role from contracts/design-tokens/v1/colors.json (bg-surface, text-accent, …).");
    process.exit(1);
  }
  console.log("colours: no raw colours outside src/shared/ui/colors.gen.css");
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
