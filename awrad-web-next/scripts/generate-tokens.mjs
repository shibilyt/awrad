// Generates src/shared/ui/tokens.gen.css from the shared shape, spacing, type and motion
// tokens (contracts/design-tokens/v1/{shape,spacing,typography,motion}.json): custom
// properties for every value, plus the Tailwind theme that names them (rounded-card,
// p-card-padding, gap-row-gap, min-h-control, max-w-content, text-title, border-checkbox,
// outline-focus-ring, …) and nothing else.
// Colours have their own generator (generate-colors.mjs).
//
//   node scripts/generate-tokens.mjs           write the file (npm run tokens:design)
//   node scripts/generate-tokens.mjs --check   fail when the committed file is stale (npm run validate)
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { kebab } from "./generate-colors.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const CONTRACTS = join(HERE, "../../contracts/design-tokens/v1");
export const SOURCES = {
  shape: join(CONTRACTS, "shape.json"),
  spacing: join(CONTRACTS, "spacing.json"),
  typography: join(CONTRACTS, "typography.json"),
  motion: join(CONTRACTS, "motion.json"),
};
export const TARGET = join(HERE, "../src/shared/ui/tokens.gen.css");

/** Tailwind's border-radius side prefixes (rounded-t-card, rounded-ss-card, …). */
const RADIUS_SIDES = ["s", "e", "t", "r", "b", "l", "ss", "se", "ee", "es", "tl", "tr", "br", "bl"];
/** CSS font-weight numbers by the names Tailwind uses (font-semibold, …). */
const WEIGHT_NAMES = {
  100: "thin",
  200: "extralight",
  300: "light",
  400: "normal",
  500: "medium",
  600: "semibold",
  700: "bold",
  800: "extrabold",
  900: "black",
};
const FULL = "calc(infinity * 1px)";
/**
 * The Tailwind font family (`--font-<key>` in theme.css, which loads the files) for each
 * family typography.json names. A style with its own fontFamily uses that family's key.
 */
export const FONT_KEYS = {
  "Google Sans Flex Rounded": "sans",
  "Noto Naskh Arabic": "arabic",
};
/** spacing.json sizes named `<name>MaxWidth` are content widths: Tailwind containers (`max-w-<name>`). */
const MAX_WIDTH = /^(.+)MaxWidth$/;

/** Reads the four token files. */
export function readTokens() {
  return Object.fromEntries(
    Object.entries(SOURCES).map(([name, path]) => [name, JSON.parse(readFileSync(path, "utf8"))]),
  );
}

function fail(message) {
  throw new Error(message);
}

function number(value, where) {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    fail(`${where} must be a non-negative number, got ${JSON.stringify(value)}`);
  }
  return value;
}

function px(value, where) {
  return `${String(number(value, where))}px`;
}

function fontKey(family, where) {
  return Object.hasOwn(FONT_KEYS, family)
    ? FONT_KEYS[family]
    : fail(`${where}: "${String(family)}" has no font in theme.css (FONT_KEYS in generate-tokens.mjs)`);
}

/** `22` → `1.375rem`: text follows the browser's text size, like sp on Android. */
function rem(px) {
  return `${String(px / 16)}rem`;
}

/** shape.json: radii, radius roles and line widths. */
function resolveShape(shape) {
  const radii = Object.entries(shape.scale).map(([name, value]) => {
    if (value === "full") return { name, css: FULL, finite: false };
    return { name, css: `${String(number(value, `shape.json scale.${name}`))}px`, finite: true };
  });
  const radiusRoles = Object.entries(shape.roles).map(([role, { radius }]) => {
    const step =
      radii.find((entry) => entry.name === radius) ?? fail(`shape.json roles.${role}: unknown radius "${radius}"`);
    return { name: kebab(role), step: step.name, finite: step.finite };
  });
  // Line widths: the only borders and outlines (README: no outlines).
  const strokes = Object.entries(shape.strokes).map(([stroke, value]) => ({
    name: kebab(stroke),
    width: px(value.width, `shape.json strokes.${stroke}.width`),
    offset: value.offset === undefined ? null : px(value.offset, `shape.json strokes.${stroke}.offset`),
  }));
  return { radii, radiusRoles, strokes };
}

/** spacing.json: the scale, roles, sizes, and the sizes that are content widths. */
function resolveSpacing(spacing) {
  const spaces = Object.entries(spacing.scale).map(([name, value]) => ({
    name,
    css: `${String(number(value, `spacing.json scale.${name}`))}px`,
  }));
  const spaceRoles = Object.entries(spacing.roles).map(([role, { space }]) => {
    if (!spaces.some((entry) => entry.name === space)) fail(`spacing.json roles.${role}: unknown space "${space}"`);
    return { name: kebab(role), step: space };
  });
  const sizes = Object.entries(spacing.sizes).map(([size, { value }]) => ({
    name: kebab(size),
    css: px(value, `spacing.json sizes.${size}`),
    container: MAX_WIDTH.exec(size)?.[1],
  }));
  return {
    spaces,
    spaceRoles,
    sizes,
    spacingSizes: sizes.filter((size) => size.container === undefined),
    containers: sizes
      .filter((size) => size.container !== undefined)
      .map((size) => ({ name: kebab(size.container ?? ""), size: size.name })),
  };
}

/** typography.json: text styles, each with its weight and, when it has one, its own font. */
function resolveTypography(typography) {
  fontKey(typography.fontFamily, "typography.json fontFamily");
  return Object.entries(typography.styles).map(([style, value]) => {
    const weight = number(value.weight, `typography.json styles.${style}.weight`);
    if (!(weight in WEIGHT_NAMES))
      fail(`typography.json styles.${style}.weight must be 100…900 in hundreds, got ${String(weight)}`);
    return {
      name: kebab(style),
      size: rem(number(value.size, `typography.json styles.${style}.size`)),
      lineHeight: rem(number(value.lineHeight, `typography.json styles.${style}.lineHeight`)),
      weight,
      tabular: value.tabularNumbers === true,
      font:
        value.fontFamily === undefined ? null : fontKey(value.fontFamily, `typography.json styles.${style}.fontFamily`),
    };
  });
}

/** motion.json: durations, easings, the web's motions and reducedMotion. */
function resolveMotion(motion) {
  const easings = Object.entries(motion.easing).map(([name, points]) => {
    if (!Array.isArray(points) || points.length !== 4 || points.some((point) => typeof point !== "number")) {
      fail(`motion.json easing.${name} must be four numbers`);
    }
    return { name: kebab(name), css: `cubic-bezier(${points.join(", ")})` };
  });
  const durations = Object.entries(motion.duration).map(([name, ms]) => ({
    name: kebab(name),
    css: `${String(number(ms, `motion.json duration.${name}`))}ms`,
  }));
  const reference = (value, where) => {
    if (typeof value === "number") return String(value);
    if (value in motion.duration) return `var(--awrad-duration-${kebab(value)})`;
    if (value in motion.easing) return `var(--awrad-ease-${kebab(value)})`;
    return fail(`${where}: "${String(value)}" is neither a duration nor an easing`);
  };
  // The web uses only the motions marked for it (fades: webPage, contentSwap).
  const webMotions = Object.entries(motion.motions)
    .filter(([, value]) => Array.isArray(value.platforms) && value.platforms.includes("web"))
    .map(([name, value]) => ({
      name: kebab(name),
      values: Object.entries(value)
        .filter(([key]) => key !== "platforms" && key !== "use")
        .map(([key, entry]) => ({ name: kebab(key), css: reference(entry, `motion.json motions.${name}.${key}`) })),
    }));
  if (!(motion.reducedMotion.duration in motion.duration)) {
    fail(`motion.json reducedMotion.duration: unknown duration "${String(motion.reducedMotion.duration)}"`);
  }
  if (!(motion.reducedMotion.easing in motion.easing)) {
    fail(`motion.json reducedMotion.easing: unknown easing "${String(motion.reducedMotion.easing)}"`);
  }
  const reducedMotion = {
    duration: `var(--awrad-duration-${kebab(motion.reducedMotion.duration)})`,
    easing: `var(--awrad-ease-${kebab(motion.reducedMotion.easing)})`,
  };
  return { easings, durations, webMotions, reducedMotion };
}

/** The tokens as named, checked values; throws on a dangling reference or a bad value. */
export function resolveTokens({ shape, spacing, typography, motion }) {
  return {
    ...resolveShape(shape),
    ...resolveSpacing(spacing),
    styles: resolveTypography(typography),
    ...resolveMotion(motion),
  };
}

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
    " * animate-*) are removed, so classes name a token: rounded-card, p-card-padding,",
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
  const plain = [...strokes, "", ...styles];
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
export function tokenNames(tokens) {
  const t = resolveTokens(tokens);
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
