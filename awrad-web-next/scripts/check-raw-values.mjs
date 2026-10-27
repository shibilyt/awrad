// Fails when a style value is written by hand instead of named from the shared design
// tokens (contracts/design-tokens/v1). Only the generated files (colors.gen.css,
// tokens.gen.css) hold values; screens name roles and tokens instead.
//
// Everywhere in src/ and index.html (whole lines):
//   - hex colours, CSS colour functions, Tailwind palette classes (text-white, bg-red-500).
// In class names (string literals in code, @apply in CSS):
//   - arbitrary values and properties: p-[13px], rounded-[10px], text-(--x), [mask:none];
//   - radius classes that aren't a shape token: rounded, rounded-none, rounded-[…];
//   - text classes that aren't a text style, colour role or alignment: text-sm, text-2xl;
//     leading-* and tracking-* (text styles carry them); weights the text styles don't use;
//   - numeric spacing and sizes: p-4, gap-1.5, min-h-11, size-5, p-px (use a spacing token);
//   - animation classes: animate-*, transition*, duration-*, delay-*, ease-* (motion is
//     fades only, in motion.css).
// In hand-written CSS (outside the generated files):
//   - raw durations and easing functions (use --awrad-duration-*, --awrad-ease-*);
//   - raw lengths in radius, spacing and text declarations.
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { SOURCE as COLORS, kebab } from "./generate-colors.mjs";
import { readTokens, tokenNames } from "./generate-tokens.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
/** Generated files, which hold the values (or aren't styles at all). */
const ALLOWED = new Set([
  "src/shared/ui/colors.gen.css",
  "src/shared/ui/tokens.gen.css",
  "src/shared/api/schema.gen.ts",
  "src/routeTree.gen.ts",
]);
const EXTENSIONS = /\.(?:css|ts|tsx|html)$/;

const PALETTE =
  "slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|black|white";
const UTILITIES =
  "bg|text|border(?:-[xytrblse])?|ring|ring-offset|outline|divide|fill|stroke|decoration|placeholder|caret|accent|shadow|inset-shadow|inset-ring|drop-shadow|text-shadow|from|via|to";
const COLOR_RULES = [
  { name: "hex colour", pattern: /(?<![\w&])#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})(?![\w-])/g },
  { name: "colour function", pattern: /\b(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch|light-dark|color)\(/g },
  {
    name: "Tailwind palette class",
    pattern: new RegExp(`(?<![\\w-])(?:${UTILITIES})-(?:${PALETTE})(?:-\\d{2,3})?(?![\\w-])`, "g"),
  },
];
const CSS_RULES = [
  { name: "raw duration", pattern: /(?<![\w-])\d*\.?\d+m?s\b/g },
  { name: "raw easing", pattern: /\b(?:cubic-bezier|steps|linear)\(/g },
  {
    name: "raw length",
    pattern:
      /\b(?:border(?:-[a-z]+)*-radius|font-size|line-height|letter-spacing|(?:padding|margin|inset|scroll-padding|scroll-margin)(?:-[a-z]+)*|gap|row-gap|column-gap)\s*:[^;]*?\d(?:px|rem|em|pt|%)/g,
  },
];

/** Tailwind's radius sides: rounded-t-card, rounded-ss-card, … */
const RADIUS_SIDES = new Set(["s", "e", "t", "r", "b", "l", "ss", "se", "ee", "es", "tl", "tr", "br", "bl"]);
/** Non-size text-* utilities: alignment, wrapping, overflow, and colour keywords. */
const TEXT_KEYWORDS = new Set([
  "left",
  "center",
  "right",
  "justify",
  "start",
  "end",
  "wrap",
  "nowrap",
  "balance",
  "pretty",
  "ellipsis",
  "clip",
  "inherit",
  "current",
  "transparent",
]);
const FONT_FAMILIES = new Set(["sans", "arabic"]);
const SPACING =
  /^(?:p[xytrblse]?|m[xytrblse]?|gap(?:-[xy])?|space-[xy]|inset(?:-[xy])?|top|right|bottom|left|start|end|(?:min-|max-)?[wh]|size|translate-[xy]|scroll-[mp][xytrblse]?|indent|basis)-(.+)$/;
const MOTION = /^(?:animate|transition|duration|delay|ease)(?:-|$)/;

/** The vocabulary the generated theme defines (tokens.gen.css, colors.gen.css). */
export function vocabulary() {
  const names = tokenNames(readTokens());
  const roles = Object.keys(JSON.parse(readFileSync(COLORS, "utf8")).roles).map(kebab);
  return {
    radius: new Set(names.radius),
    text: new Set([...names.text, ...roles]),
    font: new Set([...names.weight, ...FONT_FAMILIES]),
  };
}

/** Why a single class (`md:rounded-xl`, `p-[13px]`) isn't allowed, or null when it is. */
export function classProblem(candidate, vocab) {
  // Drop variants (hover:, data-[pressed]:, group-data-selected:) and the important flag.
  const utility =
    candidate
      .split(/:(?![^[]*\])/)
      .pop()
      ?.replace(/^!|!$/g, "")
      .replace(/^-/, "") ?? "";
  if (/^[a-z][\w-]*-[[(]|^\[[\w-]+:/.test(utility)) return "arbitrary value";
  const radius = /^rounded(?:-(.+))?$/.exec(utility);
  if (radius) {
    const value = radius[1] ?? "";
    const side = value.split("-")[0] ?? "";
    const ok = vocab.radius.has(value) || (RADIUS_SIDES.has(side) && vocab.radius.has(value.slice(side.length + 1)));
    return ok ? null : "radius that isn't a shape token";
  }
  const text = /^text-(.+?)(?:\/[\w.]+)?$/.exec(utility);
  if (text)
    return vocab.text.has(text[1] ?? "") || TEXT_KEYWORDS.has(text[1] ?? "")
      ? null
      : "text size that isn't a text style";
  if (/^(?:leading|tracking)-/.test(utility)) return "line height or tracking (text styles carry them)";
  const font = /^font-(.+)$/.exec(utility);
  if (font) return vocab.font.has(font[1] ?? "") ? null : "font weight that no text style uses";
  const spacing = SPACING.exec(utility);
  if (spacing && /^(?:\d*\.?\d+|px)$/.test(spacing[1] ?? "") && spacing[1] !== "0") return "spacing that isn't a token";
  if (MOTION.test(utility)) return "animation class (motion is fades only: motion.css)";
  return null;
}

/** The classes in a line: string literals in code, the @apply list in CSS. */
function classLists(line, kind) {
  const trimmed = line.trim();
  if (kind === "css") {
    const apply = /@apply\s+([^;]+)/.exec(line);
    return apply?.[1] === undefined ? [] : [apply[1]];
  }
  if (trimmed.startsWith("//") || trimmed.startsWith("*") || trimmed.startsWith("/*")) return [];
  return [...line.matchAll(/"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|`((?:[^`\\]|\\.)*)`/g)].map(
    (match) => match[1] ?? match[2] ?? match[3] ?? "",
  );
}

/**
 * Every raw value in a file's text, as `line: rule "match"`. `kind` is "css" for
 * stylesheets, "code" for TypeScript and HTML.
 */
export function rawValues(text, kind, vocab = vocabulary()) {
  const found = [];
  text.split("\n").forEach((line, index) => {
    const at = String(index + 1);
    const rules = kind === "css" ? [...COLOR_RULES, ...CSS_RULES] : COLOR_RULES;
    for (const { name, pattern } of rules) {
      for (const match of line.matchAll(pattern)) found.push(`${at}: ${name} "${match[0]}"`);
    }
    for (const list of classLists(line, kind)) {
      for (const candidate of list.split(/\s+/)) {
        if (candidate === "" || /[${}]/.test(candidate)) continue;
        const problem = classProblem(candidate, vocab);
        if (problem !== null) found.push(`${at}: ${problem} "${candidate}"`);
      }
    }
  });
  return found;
}

function* files(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) yield* files(path);
    else if (EXTENSIONS.test(entry.name)) yield path;
  }
}

function main() {
  const vocab = vocabulary();
  const problems = [];
  for (const path of [...files(join(ROOT, "src")), join(ROOT, "index.html")]) {
    const name = relative(ROOT, path);
    if (ALLOWED.has(name)) continue;
    const kind = name.endsWith(".css") ? "css" : "code";
    for (const problem of rawValues(readFileSync(path, "utf8"), kind, vocab)) problems.push(`${name}:${problem}`);
  }
  if (problems.length > 0) {
    console.error(problems.join("\n"));
    console.error(
      "Name a token from contracts/design-tokens/v1 instead: a colour role (bg-surface, text-accent), a shape " +
        "(rounded-card), a spacing token (p-card-padding, gap-row-gap), a text style (text-body). See ARCHITECTURE.md.",
    );
    process.exit(1);
  }
  console.log("raw values: none outside the generated token files");
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
