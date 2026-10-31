// Keeps the goal model (contracts/goal-model/v1/README.md) consistent with itself:
//   1. every case of every goal-model fixture file agrees with the reference rules in tools/goal-rules.mjs, an
//      independent reading of the README (platforms implement the rules themselves; nothing imports that file);
//   2. every goal, timeline, document and settings object a case evaluates (outside goal_validity) is valid by the
//      rules a schema can't express: session IDs derived from their kind and unique, a `between` window that isn't
//      empty, and for timelines versions in order from created_on with equal structural fields;
//   3. goal_validity agrees with the schema: a goal or document matches `goal` or `goal_document` exactly when its
//      expected errors hold none of the codes the schema expresses;
//   4. every file has a rule in the reference, so no fixture goes unchecked.
// Usage: node tools/check-goal-model.mjs
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { newAjv } from "./check-fixtures.mjs";
import { RULES, documentErrors, goalErrors, sameJson } from "./goal-rules.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const dir = join(root, "goal-model/v1/fixtures");
const ajv = newAjv();
const schema = (def) => ajv.getSchema(`urn:awrad:goal-model:1#/$defs/${def}`);
const problems = [];
let checks = 0;

// Codes the `goal_rules` schema definition expresses; the others are checked only here and by the platforms.
const SCHEMA_CODES = new Set([
  "end_date_and_duration",
  "make_up_not_allowed",
  "session_target_required",
  "sessions_with_minimum_or_cap",
  "streak_pace_not_allowed",
  "streak_threshold_value_required",
  "target_required",
]);

function inputsOf(given) {
  const found = [];
  const visit = (value) => {
    if (Array.isArray(value)) value.forEach(visit);
    else if (value && typeof value === "object") {
      if (Array.isArray(value.versions) && "created_on" in value) found.push({ kind: "timeline", value });
      else if ("schedule" in value && "count_policy" in value && "paused" in value) found.push({ kind: "goal", value });
      else Object.values(value).forEach(visit);
    }
  };
  visit(given);
  return found;
}

for (const file of readdirSync(dir).filter((f) => f.endsWith(".json")).sort()) {
  const fixture = JSON.parse(readFileSync(join(dir, file), "utf8"));
  const rule = RULES[fixture.rule];
  if (!rule) {
    problems.push(`${file}: no reference rule for "${fixture.rule}"`);
    continue;
  }
  for (const c of fixture.cases) {
    const where = `${fixture.rule} "${c.id}"`;
    checks += 1;
    let actual;
    try {
      actual = rule(c.given);
    } catch (error) {
      problems.push(`${where}: the reference rule failed: ${error.stack}`);
      continue;
    }
    if (!sameJson(actual, c.expect)) {
      problems.push(`${where}: expect ${JSON.stringify(c.expect)} but the reference gives ${JSON.stringify(actual)}`);
    }
    if (fixture.rule === "goal_validity") {
      checks += 1;
      const def = c.given.goal ? "goal" : "goal_document";
      const schemaValid = schema(def)(c.given.goal ?? c.given.document);
      const expectsSchemaError = c.expect.errors.some((e) => SCHEMA_CODES.has(e));
      if (schemaValid === expectsSchemaError) {
        problems.push(`${where}: the ${def} schema says ${schemaValid ? "valid" : "invalid"}, but the expected errors ${expectsSchemaError ? "include" : "don't include"} a schema rule`);
      }
      continue;
    }
    for (const { kind, value } of inputsOf(c.given)) {
      checks += 1;
      const errors = kind === "goal" ? goalErrors(value) : documentErrors(value);
      if (errors.size > 0) problems.push(`${where}: a ${kind} in given is invalid: ${[...errors].join(", ")}`);
    }
    if (fixture.rule === "goal_version_add") {
      checks += 1;
      const timeline = (versions) => ({ created_on: c.given.versions[0].from, versions, paused: [], excused: [] });
      const errors = new Set([
        ...documentErrors(timeline(c.given.versions)),
        ...documentErrors(timeline(c.expect.versions)),
        ...goalErrors({ ...c.given.settings, paused: [], excused: [] }),
      ]);
      if (errors.size > 0) problems.push(`${where}: the versions or settings are invalid: ${[...errors].join(", ")}`);
    }
  }
}

if (problems.length > 0) {
  for (const p of problems) console.error(p);
  process.exit(1);
}
console.log(`goal model: ${checks} checks pass (every case agrees with tools/goal-rules.mjs; inputs valid; goal_validity agrees with the schema)`);
