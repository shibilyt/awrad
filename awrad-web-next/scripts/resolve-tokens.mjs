// Reads and checks the shared shape, spacing, type and motion tokens
// (contracts/design-tokens/v1/{shape,spacing,typography,motion}.json) into named values for
// generate-tokens.mjs. Throws on a dangling reference, a bad value or a key it doesn't know
// (token-keys.mjs).
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { SOURCE as COLORS, kebab } from "./generate-colors.mjs";
import { checkKeys } from "./token-keys.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const CONTRACTS = join(HERE, "../../contracts/design-tokens/v1");
export const SOURCES = {
  shape: join(CONTRACTS, "shape.json"),
  spacing: join(CONTRACTS, "spacing.json"),
  typography: join(CONTRACTS, "typography.json"),
  motion: join(CONTRACTS, "motion.json"),
};

/** CSS font-weight numbers by the names Tailwind uses (font-semibold, …). */
export const WEIGHT_NAMES = {
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

/** The colour roles in colors.json, which elevations name. */
export function readColorRoles() {
  return new Set(Object.keys(JSON.parse(readFileSync(COLORS, "utf8")).roles));
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

/** shape.json: radii, radius roles, line widths and elevation. */
function resolveShape(shape, colorRoles) {
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
  // Elevation: the only shadows, in a colour role (`shadow` is transparent in dark).
  const elevations = Object.entries(shape.elevation ?? {}).map(([name, value]) => {
    const where = `shape.json elevation.${name}`;
    if (!colorRoles.has(value.color)) fail(`${where}.color: unknown colour role "${String(value.color)}"`);
    if (typeof value.y !== "number" || !Number.isFinite(value.y)) fail(`${where}.y must be a number`);
    const blur = px(value.blur, `${where}.blur`);
    return { name: kebab(name), css: `0 ${String(value.y)}px ${blur} var(--awrad-color-${kebab(value.color)})` };
  });
  return { radii, radiusRoles, strokes, elevations };
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
export function resolveTokens(tokens, colorRoles = readColorRoles()) {
  const { shape, spacing, typography, motion } = tokens;
  for (const [file, json] of Object.entries(tokens)) checkKeys(file, json);
  return {
    ...resolveShape(shape, colorRoles),
    ...resolveSpacing(spacing),
    styles: resolveTypography(typography),
    ...resolveMotion(motion),
  };
}
