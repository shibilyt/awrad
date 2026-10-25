// Validates every behaviour fixture file in format awrad-fixture/1 (contracts/FIXTURES.md).
// Usage: node tools/check-fixtures.mjs [dir ...]   (default: the whole contracts/ tree)
// Legacy v1 fixture files (no "format" member) are left to scripts/validate_*.py.
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const SKIP = new Set(["node_modules", "api", "tools"]);

function* jsonFiles(dir, top) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) {
      if (!(top && SKIP.has(name))) yield* jsonFiles(path, false);
    } else if (name.endsWith(".json")) {
      yield path;
    }
  }
}

/**
 * Shared model schemas (`<model>/v<N>/*.schema.json` with a `urn:awrad:` $id and draft 2020-12),
 * so fixture files can reference common definitions, e.g. `urn:awrad:goal-model:1#/$defs/goal`.
 */
const sharedSchemas = readdirSync(root)
  .filter((name) => !SKIP.has(name) && statSync(join(root, name)).isDirectory())
  .flatMap((model) =>
    readdirSync(join(root, model))
      .filter((version) => /^v\d+$/.test(version))
      .flatMap((version) =>
        readdirSync(join(root, model, version))
          .filter((file) => file.endsWith(".schema.json"))
          .map((file) => JSON.parse(readFileSync(join(root, model, version, file), "utf8"))),
      ),
  )
  .filter((schema) => String(schema.$id ?? "").startsWith("urn:awrad:") && String(schema.$schema).includes("2020-12"));

function newAjv() {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  addFormats(ajv);
  for (const schema of sharedSchemas) ajv.addSchema(schema);
  return ajv;
}

const fileSchema = JSON.parse(readFileSync(join(root, "fixture.schema.json"), "utf8"));
const validateFile = newAjv().compile(fileSchema);
const format = (errors) => errors.map((e) => `${e.instancePath || "/"} ${e.message}`).join("; ");

/** Returns the problems in one fixture file, or null if it isn't an awrad-fixture/1 file. */
export function checkFixtureFile(path) {
  let doc;
  try {
    doc = JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    return [`invalid JSON: ${error.message}`];
  }
  if (doc?.format === undefined) return null;
  if (!validateFile(doc)) return [format(validateFile.errors)];

  const problems = [];
  if (basename(path) !== `${doc.rule}.json`) problems.push(`file must be named ${doc.rule}.json`);
  const ajv = newAjv();
  let given, expect;
  try {
    given = ajv.compile(doc.given_schema);
    expect = ajv.compile(doc.expect_schema);
  } catch (error) {
    return [...problems, `invalid given_schema/expect_schema: ${error.message}`];
  }
  const seen = new Set();
  for (const c of doc.cases) {
    if (seen.has(c.id)) problems.push(`duplicate case id "${c.id}"`);
    seen.add(c.id);
    if (!given(c.given)) problems.push(`case "${c.id}" given: ${format(given.errors)}`);
    if (!expect(c.expect)) problems.push(`case "${c.id}" expect: ${format(expect.errors)}`);
  }
  return problems;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const dirs = process.argv.slice(2);
  const files = dirs.length ? dirs.flatMap((d) => [...jsonFiles(d, false)]) : [...jsonFiles(root, true)];
  let checked = 0;
  let failed = false;
  for (const file of files) {
    const problems = checkFixtureFile(file);
    if (problems === null) continue;
    checked += 1;
    for (const p of problems) {
      failed = true;
      console.error(`${relative(root, file)}: ${p}`);
    }
  }
  if (failed) process.exit(1);
  console.log(`fixtures: ${checked} awrad-fixture/1 file(s) valid`);
}
