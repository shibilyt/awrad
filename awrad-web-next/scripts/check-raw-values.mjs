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
//   - numeric spacing and sizes: p-4, gap-1.5, min-h-11, h-12, size-5, p-px (use a spacing
//     token such as min-h-control);
//   - max widths that aren't a content width or spacing token: max-w-page, max-w-prose;
//   - border, outline and ring widths: border, border-2, outline-2, outline-offset-2, ring
//     (use a stroke: border-checkbox, border-field-error, outline-focus-ring);
//   - numeric opacity on a disabled control: disabled:opacity-50 (use opacity-disabled);
//   - shadows other than an elevation token: shadow, shadow-lg, drop-shadow-md, text-shadow-sm
//     (use shadow-floating);
//   - animation classes: animate-*, transition*, duration-*, delay-*, ease-* (motion is
//     fades only, in motion.css).
// In hand-written CSS (outside the generated files):
//   - raw durations, easing functions and easing keywords in animations and transitions
//     (use --awrad-duration-*, --awrad-ease-*);
//   - raw lengths in radius, spacing, text, border-width, outline and shadow declarations.
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
    name: "raw easing",
    pattern:
      /\b(?:animation|transition)(?:-timing-function)?\s*:[^;]*?(?<![\w-])(?:linear|ease(?:-in|-out|-in-out)?|step-start|step-end)(?![\w-])/g,
  },
  {
    name: "raw length",
    pattern:
      /\b(?:box-shadow|text-shadow|border(?:-[a-z]+)*-(?:radius|width)|border(?:-(?:top|right|bottom|left|block|inline)(?:-start|-end)?)?|outline(?:-width|-offset)?|font-size|line-height|letter-spacing|(?:padding|margin|inset|scroll-padding|scroll-margin)(?:-[a-z]+)*|gap|row-gap|column-gap)\s*:[^;]*?\d(?:px|rem|em|pt|%)/g,
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
/** Line widths in px (border, border-2, border-x, outline-2, outline-offset-2, ring, divide-y): shape.json strokes name them. */
const LINE_WIDTH =
  /^(?:border(?:-(?:[xytrblse]|s[se]|e[se]))?|outline(?:-offset)?|ring(?:-offset)?|inset-ring|divide-[xy])(?:-(?:\d*\.?\d+|px))?$/;
/** max-w-* keywords that aren't lengths. */
const MAX_WIDTH_KEYWORDS = new Set(["none", "full", "min", "max", "fit", "screen", "dvw", "svw", "lvw", "auto"]);
/** Variants that style a disabled control. */
/** Shadow utilities: only an elevation (shadow-floating) is allowed. */
const SHADOW = /^(?:inset-|drop-|text-)?shadow(?:-|$)/;
const DISABLED = /^(?:(?:group|peer)-)?(?:disabled|data-disabled|aria-disabled)$/;

/** The vocabulary the generated theme defines (tokens.gen.css, colors.gen.css). */
export function vocabulary() {
  const names = tokenNames(readTokens());
  const roles = Object.keys(JSON.parse(readFileSync(COLORS, "utf8")).roles).map(kebab);
  return {
    radius: new Set(names.radius),
    text: new Set([...names.text, ...roles]),
    font: new Set([...names.weight, ...FONT_FAMILIES]),
    maxWidth: new Set([...names.container, ...names.space, ...MAX_WIDTH_KEYWORDS]),
    shadow: new Set(names.shadow),
  };
}

/** Why a single class (`md:rounded-xl`, `p-[13px]`) isn't allowed, or null when it is. */
export function classProblem(candidate, vocab) {
  // Drop variants (hover:, data-[pressed]:, group-data-selected:) and the important flag.
  const variants = candidate.split(/:(?![^[]*\])/);
  const utility = variants.pop()?.replace(/^!|!$/g, "").replace(/^-/, "") ?? "";
  if (/^[a-z][\w-]*-[[(]|^\[[\w-]+:/.test(utility)) return "arbitrary value";
  if (SHADOW.test(utility) && !vocab.shadow.has(utility.replace(/^shadow-/, ""))) {
    return "shadow that isn't an elevation token (shadow-floating)";
  }
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
  const maxWidth = /^max-w-(.+)$/.exec(utility);
  if (maxWidth && !vocab.maxWidth.has(maxWidth[1] ?? "") && !/^\d+\/\d+$/.test(maxWidth[1] ?? "")) {
    return "max width that isn't a token";
  }
  if (LINE_WIDTH.test(utility)) return "line width that isn't a stroke token";
  if (/^opacity-\d/.test(utility) && variants.some((variant) => DISABLED.test(variant))) {
    return "disabled opacity that isn't the state token (opacity-disabled)";
  }
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
        "(rounded-card), a spacing token (p-card-padding, gap-row-gap, min-h-control), a content width (max-w-content), " +
        "a stroke (border-checkbox, outline-focus-ring), an elevation (shadow-floating), a state (disabled:opacity-disabled), a text style (text-body). " +
        "See ARCHITECTURE.md.",
    );
    process.exit(1);
  }
  console.log("raw values: none outside the generated token files");
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
