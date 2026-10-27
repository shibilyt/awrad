// Validates the shared data catalogs that aren't fixtures: the Hijri month table and the goal presets.
// Usage: node tools/check-catalogs.mjs
import { createHash } from "node:crypto";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { newAjv } from "./check-fixtures.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const read = (path) => JSON.parse(readFileSync(join(root, path), "utf8"));
const ajv = newAjv();
const problems = [];

function validate(path, ref, doc) {
  const check = ajv.getSchema(ref);
  if (!check(doc))
    for (const e of check.errors)
      problems.push(`${path}: ${e.instancePath || "/"} ${e.message}`);
}

const DAY = 86_400_000;
const days = (a, b) => (Date.parse(b) - Date.parse(a)) / DAY;

// Hijri table: every year present, 12 increasing starts, every month 29 or 30 days, up to end_exclusive.
const tablePath = "hijri-calendar/v1/umm-al-qura.json";
const table = read(tablePath);
validate(tablePath, "urn:awrad:hijri-calendar:1#/$defs/table", table);
const starts = [];
for (let year = table.first_year; year <= table.last_year; year += 1) {
  const months = table.month_starts[String(year)];
  if (!months) problems.push(`${tablePath}: year ${year} missing`);
  else
    starts.push(
      ...months.map((date, i) => ({ date, label: `${year}/${i + 1}` })),
    );
}
if (
  Object.keys(table.month_starts).length !==
  table.last_year - table.first_year + 1
)
  problems.push(
    `${tablePath}: month_starts must hold exactly first_year..last_year`,
  );
starts.push({ date: table.end_exclusive, label: "end_exclusive" });
for (let i = 0; i + 1 < starts.length; i += 1) {
  const length = days(starts[i].date, starts[i + 1].date);
  if (length !== 29 && length !== 30)
    problems.push(`${tablePath}: ${starts[i].label} has ${length} days`);
}

// Goal presets: schema-valid, unique keys.
const presetsPath = "goal-presets/v1/goal-presets.json";
const presets = read(presetsPath);
validate(presetsPath, "urn:awrad:goal-presets:1", presets);
const keys = new Set();
for (const { key } of presets.presets ?? []) {
  if (keys.has(key)) problems.push(`${presetsPath}: duplicate key "${key}"`);
  keys.add(key);
}

// Design tokens: schema-valid, every colour from the palette, every listed pair meets its contrast minimum in both themes.
const tokensPath = "design-tokens/v1/colors.json";
const tokens = read(tokensPath);
validate(tokensPath, "urn:awrad:design-tokens:1#/$defs/colors", tokens);
const palette = new Set(Object.values(tokens.palette ?? {}));
const rgb = (hex) =>
  [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
const alpha = (hex) =>
  hex.length === 9 ? parseInt(hex.slice(7, 9), 16) / 255 : 1;
const over = (fg, bg) =>
  rgb(fg).map((c, i) => alpha(fg) * c + (1 - alpha(fg)) * rgb(bg)[i]);
const luminance = (c) =>
  c
    .map((x) => (x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4))
    .reduce((sum, x, i) => sum + x * [0.2126, 0.7152, 0.0722][i], 0);
const ratio = (a, b) => {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};
let pairs = 0;
for (const [name, role] of Object.entries(tokens.roles ?? {})) {
  for (const theme of ["light", "dark"]) {
    if (!palette.has(role[theme].slice(0, 7)))
      problems.push(
        `${tokensPath}: ${name}.${theme} ${role[theme]} isn't in the palette`,
      );
  }
}
for (const { foreground, background, minimum } of tokens.contrast ?? []) {
  const fg = tokens.roles[foreground];
  const bg = tokens.roles[background];
  if (!fg || !bg) {
    problems.push(
      `${tokensPath}: contrast pair ${foreground}/${background} names an unknown role`,
    );
    continue;
  }
  for (const theme of ["light", "dark"]) {
    if (alpha(bg[theme]) !== 1)
      problems.push(
        `${tokensPath}: ${background}.${theme} must be opaque to be a contrast background`,
      );
    const got = ratio(over(fg[theme], bg[theme]), rgb(bg[theme]));
    if (got < minimum)
      problems.push(
        `${tokensPath}: ${foreground} on ${background} (${theme}) is ${got.toFixed(2)}:1, needs ${minimum}`,
      );
    pairs += 1;
  }
}

// Shape, spacing, type and motion: schema-valid, and every name a token refers to exists.
const shape = read("design-tokens/v1/shape.json");
const spacing = read("design-tokens/v1/spacing.json");
const typography = read("design-tokens/v1/typography.json");
const motion = read("design-tokens/v1/motion.json");
validate(
  "design-tokens/v1/shape.json",
  "urn:awrad:design-tokens:1#/$defs/shape",
  shape,
);
validate(
  "design-tokens/v1/spacing.json",
  "urn:awrad:design-tokens:1#/$defs/spacing",
  spacing,
);
validate(
  "design-tokens/v1/typography.json",
  "urn:awrad:design-tokens:1#/$defs/typography",
  typography,
);
validate(
  "design-tokens/v1/motion.json",
  "urn:awrad:design-tokens:1#/$defs/motion",
  motion,
);
const refs = (file, owner, value, table, kind) => {
  if (!(value in (table ?? {})))
    problems.push(`${file}: ${owner} names unknown ${kind} "${value}"`);
};
for (const [name, role] of Object.entries(shape.roles ?? {}))
  refs("shape.json", name, role.radius, shape.scale, "radius");
for (const [name, role] of Object.entries(spacing.roles ?? {}))
  refs("spacing.json", name, role.space, spacing.scale, "space");
// In motion.json, fields ending in Spring/spring name a spring, duration-like fields a duration, Easing/easing an easing,
// haptic a haptic, radius a shape role.
const motionRef = (owner, key, value) => {
  if (typeof value !== "string") return;
  if (/^spring$|Spring$/.test(key))
    refs("motion.json", `${owner}.${key}`, value, motion.spring, "spring");
  else if (/^duration$|Duration$|^fadeIn$|^fadeOut$/.test(key))
    refs("motion.json", `${owner}.${key}`, value, motion.duration, "duration");
  else if (/^easing$|Easing$/.test(key))
    refs("motion.json", `${owner}.${key}`, value, motion.easing, "easing");
  else if (key === "haptic")
    refs("motion.json", `${owner}.${key}`, value, motion.haptic, "haptic");
  else if (key === "radius")
    refs("motion.json", `${owner}.${key}`, value, shape.roles, "shape role");
};
const walk = (owner, node) => {
  for (const [key, value] of Object.entries(node)) {
    if (value && typeof value === "object" && !Array.isArray(value))
      walk(`${owner}.${key}`, value);
    else motionRef(owner, key, value);
  }
};
for (const [name, spec] of Object.entries(motion.motions ?? {}))
  walk(name, spec);
refs(
  "motion.json",
  "reducedMotion.duration",
  motion.reducedMotion?.duration,
  motion.duration,
  "duration",
);
refs(
  "motion.json",
  "reducedMotion.easing",
  motion.reducedMotion?.easing,
  motion.easing,
  "easing",
);

// Fonts: every file listed in SHA256SUMS exists and matches, and every .ttf is listed.
const fontsDir = "design-tokens/v1/fonts";
const sums = readFileSync(join(root, fontsDir, "SHA256SUMS"), "utf8")
  .trim()
  .split("\n")
  .map((line) => line.split(/\s+/));
for (const [sum, file] of sums) {
  const actual = createHash("sha256")
    .update(readFileSync(join(root, fontsDir, file)))
    .digest("hex");
  if (actual !== sum)
    problems.push(`${fontsDir}/${file}: checksum differs from SHA256SUMS`);
}
const listed = new Set(sums.map(([, file]) => file));
for (const file of readdirSync(join(root, fontsDir)).filter((f) =>
  f.endsWith(".ttf"),
)) {
  if (!listed.has(file))
    problems.push(`${fontsDir}/${file}: not listed in SHA256SUMS`);
}

// Every font family a text style names is bundled: "Noto Naskh Arabic" needs notonaskharabic_*.ttf.
const ttfs = readdirSync(join(root, fontsDir)).filter((f) => f.endsWith(".ttf"));
for (const [name, style] of Object.entries({ "": { fontFamily: typography.fontFamily }, ...typography.styles })) {
  const family = style.fontFamily;
  if (family === undefined) continue;
  const prefix = family.toLowerCase().replaceAll(" ", "") + "_";
  if (!ttfs.some((f) => f.startsWith(prefix)))
    problems.push(`typography.json: ${name || "fontFamily"} uses "${family}", which has no file in ${fontsDir}`);
}

if (problems.length) {
  for (const p of problems) console.error(p);
  process.exit(1);
}
console.log(
  `catalogs: Hijri table ${starts.length - 1} months valid; ${keys.size} goal presets valid; ` +
    `${Object.keys(tokens.roles).length} colour roles, ${pairs} contrast checks pass; ${sums.length} font files match; ` +
    `${Object.keys(shape.roles).length} shape, ${Object.keys(spacing.roles).length} spacing, ` +
    `${Object.keys(typography.styles).length} type and ${Object.keys(motion.motions).length} motion tokens valid`,
);
