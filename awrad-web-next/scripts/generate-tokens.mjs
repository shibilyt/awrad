// Generates src/shared/ui/tokens.gen.css from the shared shape, spacing, type and motion
// tokens (contracts/design-tokens/v1/{shape,spacing,typography,motion}.json): custom
// properties for every value, plus the Tailwind theme that names them (rounded-card,
// p-card-padding, gap-row-gap, min-h-control, max-w-content, text-title, border-checkbox,
// outline-focus-ring, shadow-floating, …) and nothing else. A key the generator doesn't know
// fails (token-keys.mjs). Colours have their own generator (generate-colors.mjs).
//
//   node scripts/generate-tokens.mjs           write the file (npm run tokens:design)
//   node scripts/generate-tokens.mjs --check   fail when the committed file is stale (npm run validate)
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { WEIGHT_NAMES, readTokens, resolveTokens } from "./resolve-tokens.mjs";

export { FONT_KEYS, SOURCES, readTokens, resolveTokens } from "./resolve-tokens.mjs";

export const TARGET = join(dirname(fileURLToPath(import.meta.url)), "../src/shared/ui/tokens.gen.css");

/** Tailwind's border-radius side prefixes (rounded-t-card, rounded-ss-card, …). */
const RADIUS_SIDES = ["s", "e", "t", "r", "b", "l", "ss", "se", "ee", "es", "tl", "tr", "br", "bl"];

/** spacing.json's `none` is Tailwind's 0 (p-0, inset-0, min-w-0): `*-none` would clash with max-w-none. */
function spacingKey(name) {
  return name === "none" ? "0" : name;
}

/** Every value as an `--awrad-*` custom property. */
function rootLines(t) {
  return [
    ":root {",
    "  /* Corner radii (shape.json): the scale, then the roles. */",
    ...t.radii.map((step) => `  --awrad-radius-${step.name}: ${step.css};`),
    ...t.radiusRoles.map((role) => `  --awrad-radius-${role.name}: var(--awrad-radius-${role.step});`),
    "",
    "  /* Line widths (shape.json strokes), the only lines: a width and, for a ring, its offset. */",
    ...t.strokes.flatMap((stroke) => [
      `  --awrad-stroke-${stroke.name}: ${stroke.width};`,
      ...(stroke.offset === null ? [] : [`  --awrad-stroke-${stroke.name}-offset: ${stroke.offset};`]),
    ]),
    "",
    "  /* Elevation (shape.json): the only shadows, in the `shadow` colour role. */",
    ...t.elevations.map((elevation) => `  --awrad-elevation-${elevation.name}: ${elevation.css};`),
    "",
    "  /* Spacing (spacing.json): the scale, the roles, then the standard sizes and content widths. */",
    ...t.spaces.map((step) => `  --awrad-space-${step.name}: ${step.css};`),
    ...t.spaceRoles.map((role) => `  --awrad-space-${role.name}: var(--awrad-space-${role.step});`),
    ...t.sizes.map((size) => `  --awrad-size-${size.name}: ${size.css};`),
    "",
    "  /* Text styles (typography.json), in rem (1rem = 16px) so they follow the browser's text size. */",
    ...t.styles.flatMap((style) => [
      `  --awrad-text-${style.name}-size: ${style.size};`,
      `  --awrad-text-${style.name}-line-height: ${style.lineHeight};`,
      `  --awrad-text-${style.name}-weight: ${String(style.weight)};`,
      ...(style.font === null ? [] : [`  --awrad-text-${style.name}-font-family: var(--font-${style.font});`]),
    ]),
    "",
    "  /* Motion (motion.json). The web uses only fades: durations, easings, its motions and reducedMotion. */",
    ...t.easings.map((easing) => `  --awrad-ease-${easing.name}: ${easing.css};`),
    ...t.durations.map((duration) => `  --awrad-duration-${duration.name}: ${duration.css};`),
    ...t.webMotions.flatMap((motion) =>
      motion.values.map((value) => `  --awrad-motion-${motion.name}-${value.name}: ${value.css};`),
    ),
    `  --awrad-reduced-motion-duration: ${t.reducedMotion.duration};`,
    `  --awrad-reduced-motion-easing: ${t.reducedMotion.easing};`,
    "}",
  ];
}

/** Tailwind's theme: the tokens replace its radius, spacing, text and weight scales. */
function themeLines(t) {
  const weights = [...new Set(t.styles.map((style) => style.weight))].sort((a, b) => a - b);
  return [
    "/*",
    " * Tailwind: these are the only radii, spacing, sizes, content widths, text styles and weights.",
    " * Tailwind's defaults (rounded-xl, p-4, max-w-md, text-sm, leading-*, tracking-*, ease-*,",
    " * animate-*, shadow-*) are removed, so classes name a token: rounded-card, p-card-padding,",
    " * gap-row-gap, min-h-control, max-w-content, text-title, font-semibold.",
    " */",
    "@theme inline {",
    "  --radius-*: initial;",
    ...[...t.radii, ...t.radiusRoles].map((entry) => `  --radius-${entry.name}: var(--awrad-radius-${entry.name});`),
    "  --spacing-*: initial;",
    ...t.spaces.map((step) => `  --spacing-${spacingKey(step.name)}: var(--awrad-space-${step.name});`),
    ...t.spaceRoles.map((role) => `  --spacing-${role.name}: var(--awrad-space-${role.name});`),
    ...t.spacingSizes.map((size) => `  --spacing-${size.name}: var(--awrad-size-${size.name});`),
    "  --container-*: initial;",
    ...t.containers.map((container) => `  --container-${container.name}: var(--awrad-size-${container.size});`),
    "  --text-*: initial;",
    ...t.styles.flatMap((style) => [
      `  --text-${style.name}: var(--awrad-text-${style.name}-size);`,
      `  --text-${style.name}--line-height: var(--awrad-text-${style.name}-line-height);`,
      `  --text-${style.name}--font-weight: var(--awrad-text-${style.name}-weight);`,
    ]),
    "  --font-weight-*: initial;",
    ...weights.map((weight) => `  --font-weight-${WEIGHT_NAMES[weight]}: ${String(weight)};`),
    "  --leading-*: initial;",
    "  --tracking-*: initial;",
    "  --ease-*: initial;",
    "  --animate-*: initial;",
    "  --shadow-*: initial;",
    "  --inset-shadow-*: initial;",
    "  --drop-shadow-*: initial;",
    "  --text-shadow-*: initial;",
    "}",
  ];
}

/**
 * What a theme value can't say: line widths, text styles' own digits and font family,
 * and continuous corners when shape.json asks for them.
 */
function utilityLines(t, corners) {
  const squircles = [...t.radii, ...t.radiusRoles].filter((entry) => entry.finite).map((entry) => entry.name);
  const strokes = [
    "/*",
    " * Line widths (shape.json strokes): each stroke as a border width (border-field-error,",
    " * border-checkbox) or a solid outline (outline-focus-ring, with outline-offset-focus-ring).",
    " * Pair with a colour role: border-error, outline-accent.",
    " */",
    ...t.strokes.flatMap((stroke) => [
      `@utility border-${stroke.name} {`,
      `  border-width: var(--awrad-stroke-${stroke.name});`,
      "}",
      `@utility outline-${stroke.name} {`,
      "  outline-style: solid;",
      `  outline-width: var(--awrad-stroke-${stroke.name});`,
      "}",
      ...(stroke.offset === null
        ? []
        : [
            `@utility outline-offset-${stroke.name} {`,
            `  outline-offset: var(--awrad-stroke-${stroke.name}-offset);`,
            "}",
          ]),
    ]),
  ];
  const styles = [
    "/* Text styles with tabular digits or their own font family. */",
    ...t.styles
      .filter((style) => style.tabular || style.font !== null)
      .flatMap((style) => [
        `@utility text-${style.name} {`,
        ...(style.tabular ? ["  font-variant-numeric: tabular-nums;"] : []),
        ...(style.font === null ? [] : [`  font-family: var(--awrad-text-${style.name}-font-family);`]),
        "}",
      ]),
  ];
  const shadows = [
    "/* Elevation (shape.json): shadow-<elevation> is the only shadow class. */",
    ...t.elevations.flatMap((elevation) => [
      `@utility shadow-${elevation.name} {`,
      `  box-shadow: var(--awrad-elevation-${elevation.name});`,
      "}",
    ]),
  ];
  const plain = [...strokes, "", ...styles, "", ...shadows];
  if (corners !== "continuous") return plain;
  return [
    ...plain,
    "",
    "/*",
    " * Continuous corners (shape.json `corners`): corner-shape: squircle where the browser",
    " * supports it, plain rounding elsewhere. Fully rounded shapes (chips, round buttons) stay round.",
    " */",
    "@theme inline reference {",
    ...squircles.map((name) => `  --corner-shape-${name}: squircle;`),
    "}",
    ...["", ...RADIUS_SIDES.map((side) => `${side}-`)].flatMap((side) => [
      `@utility rounded-${side}* {`,
      "  @supports (corner-shape: squircle) {",
      "    corner-shape: --value(--corner-shape-*);",
      "  }",
      "}",
    ]),
  ];
}

/** The CSS for the parsed token files. */
export function renderTokensCss(tokens) {
  const t = resolveTokens(tokens);
  return [
    "/*",
    " * Generated by scripts/generate-tokens.mjs from contracts/design-tokens/v1/",
    " * shape.json, spacing.json, typography.json and motion.json.",
    " * Don't edit: run `npm run tokens:design`. `npm run validate` fails when this file is stale.",
    " */",
    "",
    ...rootLines(t),
    "",
    ...themeLines(t),
    "",
    ...utilityLines(t, tokens.shape.corners),
    "",
  ].join("\n");
}

/** Every class name the generated theme defines, for check-raw-values.mjs. */
export function tokenNames(tokens, colorRoles) {
  const t = resolveTokens(tokens, colorRoles);
  return {
    radius: [...t.radii.map((step) => step.name), ...t.radiusRoles.map((role) => role.name)],
    stroke: t.strokes.map((stroke) => stroke.name),
    space: [
      ...t.spaces.map((step) => spacingKey(step.name)),
      ...t.spaceRoles.map((role) => role.name),
      ...t.spacingSizes.map((size) => size.name),
    ],
    container: t.containers.map((container) => container.name),
    text: t.styles.map((style) => style.name),
    weight: [...new Set(t.styles.map((style) => WEIGHT_NAMES[style.weight]))],
    shadow: t.elevations.map((elevation) => elevation.name),
  };
}

function main() {
  const css = renderTokensCss(readTokens());
  if (process.argv.includes("--check")) {
    let committed = "";
    try {
      committed = readFileSync(TARGET, "utf8");
    } catch {
      // A missing file is stale too.
    }
    if (committed !== css) {
      console.error("src/shared/ui/tokens.gen.css is stale or edited by hand. Run: npm run tokens:design");
      process.exit(1);
    }
    console.log("tokens: up to date with contracts/design-tokens/v1 (shape, spacing, typography, motion)");
    return;
  }
  writeFileSync(TARGET, css);
  console.log("wrote src/shared/ui/tokens.gen.css");
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
