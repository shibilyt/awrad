// Validates the shared data catalogs that aren't fixtures: the Hijri month table and the goal presets.
// Usage: node tools/check-catalogs.mjs
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { newAjv } from "./check-fixtures.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const read = (path) => JSON.parse(readFileSync(join(root, path), "utf8"));
const ajv = newAjv();
const problems = [];

function validate(path, ref, doc) {
  const check = ajv.getSchema(ref);
  if (!check(doc)) for (const e of check.errors) problems.push(`${path}: ${e.instancePath || "/"} ${e.message}`);
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
  else starts.push(...months.map((date, i) => ({ date, label: `${year}/${i + 1}` })));
}
if (Object.keys(table.month_starts).length !== table.last_year - table.first_year + 1)
  problems.push(`${tablePath}: month_starts must hold exactly first_year..last_year`);
starts.push({ date: table.end_exclusive, label: "end_exclusive" });
for (let i = 0; i + 1 < starts.length; i += 1) {
  const length = days(starts[i].date, starts[i + 1].date);
  if (length !== 29 && length !== 30) problems.push(`${tablePath}: ${starts[i].label} has ${length} days`);
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

if (problems.length) {
  for (const p of problems) console.error(p);
  process.exit(1);
}
console.log(`catalogs: Hijri table ${starts.length - 1} months valid; ${keys.size} goal presets valid`);
