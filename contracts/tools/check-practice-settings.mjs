// Keeps the slice 3d contracts consistent (practice-settings/v1/README.md, places/v1/README.md):
//   1. every case of practice_policy_validity, practice_policy_merge, practice_policy_first_sign_in, maghrib_time
//      and city_search says exactly what the reference rules in tools/practice-settings-rules.mjs compute (Maghrib
//      from the adhan library, to the minute);
//   2. practice_policy_validity agrees with the schema: a document the schema refuses has a schema-level error, and
//      a document it accepts fails only on duplicate months or month lengths;
//   3. the policies the merge and first-sign-in cases start from are valid, and maghrib_time covers every method;
//   4. places/v1/cities.json matches its schema, has unique IDs in order, and respects the population thresholds;
//   5. in sync/v1 apply_changes.json, a conflict on a practice_policy gives the merge rule's document, base, queued
//      put and notice;
//   6. the OpenAPI restatement PracticePolicyDocument keeps the schema's members, values and correction bounds.
// Usage: node tools/check-practice-settings.mjs
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { newAjv } from "./check-fixtures.mjs";
import { firstSignIn, maghrib, mergePolicy, policyErrors, searchCities } from "./practice-settings-rules.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const read = (path) => JSON.parse(readFileSync(join(root, path), "utf8"));
const ajv = newAjv();
const policySchema = ajv.getSchema("urn:awrad:practice-settings:1#/$defs/practice_policy_document");
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const problems = [];
let checks = 0;

function compare(rule, c, actual) {
  checks += 1;
  if (!same(actual, c.expect)) problems.push(`${rule} "${c.id}": expected ${JSON.stringify(c.expect)}, the rule gives ${JSON.stringify(actual)}`);
}
function validPolicy(document, where) {
  checks += 1;
  if (!policySchema(document) || policyErrors(document).length > 0) problems.push(`${where}: not a valid practice_policy document`);
}

// 1-2. practice_policy_validity
const RULE_ONLY = new Set(["duplicate", "range"]);
for (const c of read("practice-settings/v1/fixtures/practice_policy_validity.json").cases) {
  const errors = policyErrors(c.given.document);
  compare("practice_policy_validity", c, { valid: errors.length === 0, errors });
  checks += 1;
  const schemaValid = policySchema(c.given.document);
  if (schemaValid && errors.some((e) => !RULE_ONLY.has(e.code))) problems.push(`practice_policy_validity "${c.id}": the schema accepts it, so only duplicate or range errors may apply`);
  if (!schemaValid && errors.every((e) => RULE_ONLY.has(e.code))) problems.push(`practice_policy_validity "${c.id}": the schema refuses it, so it needs a schema-level error`);
}

// 1, 3. practice_policy_merge and practice_policy_first_sign_in
for (const c of read("practice-settings/v1/fixtures/practice_policy_merge.json").cases) {
  for (const side of ["base", "mine", "theirs"]) validPolicy(c.given[side], `practice_policy_merge "${c.id}" ${side}`);
  compare("practice_policy_merge", c, mergePolicy(c.given.base, c.given.mine, c.given.theirs));
  validPolicy(c.expect.document, `practice_policy_merge "${c.id}" expect`);
}
for (const c of read("practice-settings/v1/fixtures/practice_policy_first_sign_in.json").cases) {
  validPolicy(c.given.local.document, `practice_policy_first_sign_in "${c.id}" local`);
  compare("practice_policy_first_sign_in", c, firstSignIn(c.given));
}

// 1, 3. maghrib_time
const methods = new Set(read("practice-settings/v1/practice-settings.schema.json").$defs.calculation_method.enum);
for (const c of read("practice-settings/v1/fixtures/maghrib_time.json").cases) {
  compare("maghrib_time", c, { maghrib: maghrib(c.given) });
  methods.delete(c.given.calculation_method);
}
checks += 1;
if (methods.size > 0) problems.push(`maghrib_time: no case for ${[...methods].join(", ")}`);

// 4. cities.json
const list = read("places/v1/cities.json");
const validList = ajv.getSchema("urn:awrad:places:1#/$defs/city_list");
checks += 1;
if (!validList(list)) problems.push(`places/v1/cities.json: ${ajv.errorsText(validList.errors)}`);
const { thresholds } = list;
const lowered = new Set(Object.keys(thresholds.regions).map((key) => key.split(".")[0]));
const lowest = Math.min(thresholds.default, ...Object.values(thresholds.regions));
list.cities.forEach((city, i) => {
  checks += 1;
  if (i > 0 && list.cities[i - 1].id >= city.id) problems.push(`places/v1/cities.json: ${city.id} isn't after ${list.cities[i - 1].id}`);
  const min = lowered.has(city.country) ? lowest : thresholds.default;
  if (city.population < min) problems.push(`places/v1/cities.json: ${city.name} (${city.id}) has ${city.population} people, under ${min}`);
});

// 1. city_search
for (const c of read("places/v1/fixtures/city_search.json").cases) {
  compare("city_search", c, { city_ids: searchCities(list.cities, c.given.query, c.given.limit) });
}

// 5. apply_changes: practice_policy conflicts merge by setting
for (const c of read("sync/v1/fixtures/apply_changes.json").cases) {
  if (c.given.step.kind !== "receipts") continue;
  const sent = c.given.local.outbox.filter((command) => command.sent);
  c.given.step.receipts.forEach((receipt, i) => {
    if (receipt.status !== "conflict" || sent[i]?.entity_type !== "practice_policy") return;
    checks += 1;
    const where = `apply_changes "${c.id}"`;
    const before = c.given.local.entities.find((e) => e.entity_type === "practice_policy");
    const after = c.expect.local.entities.find((e) => e.entity_type === "practice_policy");
    const theirs = receipt.current.document;
    const merged = mergePolicy(before.base_document, before.document, theirs);
    const queued = c.expect.local.outbox.filter((command) => command.entity_type === "practice_policy");
    const wantQueued = merged.requeue ? [{ op: "put", base_version: receipt.current.version, document: merged.document, sent: false }] : [];
    const gotQueued = queued.map(({ op, base_version, document, sent: s }) => ({ op, base_version, document, sent: s }));
    const notices = c.expect.notices.filter((n) => n.entity_type === "practice_policy").map((n) => n.code);
    if (!same(after.document, merged.document) || !same(after.base_document, theirs) || after.known_version !== receipt.current.version) {
      problems.push(`${where}: the policy becomes the merge of base_document, the local document and the server's, with the server's as base and version`);
    }
    if (!same(gotQueued, wantQueued)) problems.push(`${where}: queued should be ${JSON.stringify(wantQueued)}`);
    if (!same(notices, merged.notice ? [merged.notice] : [])) problems.push(`${where}: notices should be ${JSON.stringify(merged.notice ? [merged.notice] : [])}`);
    if (c.expect.local.conflicts.some((x) => x.entity_type === "practice_policy")) problems.push(`${where}: a practice_policy conflict never opens a conflict`);
  });
}

// 6. OpenAPI restatement
const defs = read("practice-settings/v1/practice-settings.schema.json").$defs;
const restated = read("api/openapi.bundled.json").components.schemas.PracticePolicyDocument;
const correction = read("hijri-calendar/v1/hijri-calendar.schema.json").$defs.correction.properties;
const hijriYear = read("hijri-calendar/v1/hijri-calendar.schema.json").$defs.hijri_year;
const item = restated.properties.hijri_corrections.items.properties;
for (const [what, openapi, contract] of [
  ["members", restated.required, defs.practice_policy_document.required],
  ["day_reset", restated.properties.day_reset.enum, defs.day_reset.enum],
  ["calculation_method", restated.properties.calculation_method.enum, defs.calculation_method.enum],
  ["madhab", restated.properties.madhab.enum, defs.madhab.enum],
  ["week_start", restated.properties.week_start.enum, read("goal-model/v1/goal-model.schema.json").$defs.week_start.enum],
  ["year bounds", [item.year.minimum, item.year.maximum], [hijriYear.minimum, hijriYear.maximum]],
  ["offset bounds", [item.offset_days.minimum, item.offset_days.maximum], [correction.offset_days.minimum, correction.offset_days.maximum]],
]) {
  checks += 1;
  if (!same(openapi, contract)) problems.push(`OpenAPI PracticePolicyDocument ${what} ${JSON.stringify(openapi)} differ from the contract's ${JSON.stringify(contract)}`);
}

if (problems.length > 0) {
  for (const p of problems) console.error(p);
  process.exit(1);
}
console.log(`practice settings: ${checks} checks pass (policy validity, merge, first sign-in, Maghrib from adhan, ${list.cities.length} cities, city search)`);
