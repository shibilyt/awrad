// Keeps the change-queue contract consistent with itself (contracts/sync/v1/README.md):
//   1. every example of the sync operations in api/openapi.bundled.json matches sync/v1/sync.schema.json, which
//      the OpenAPI restates (its bundler can't follow urn: references);
//   2. custom_dhikr_validity.json says "valid" exactly when the document matches $defs/custom_dhikr_document;
//   3. every command in sync_receipts.json that isn't rejected is a valid $defs/command;
//   4. every name tag_name_normalization.json accepts makes a valid $defs/user_tag_document.
// Usage: node tools/check-sync-contract.mjs
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { newAjv } from "./check-fixtures.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const read = (path) => JSON.parse(readFileSync(join(root, path), "utf8"));
const ajv = newAjv();
const schema = (def) => ajv.getSchema(`urn:awrad:sync:1#/$defs/${def}`);
const problems = [];
let checks = 0;

function expectValid(def, value, where) {
  checks += 1;
  const validate = schema(def);
  if (!validate(value)) {
    problems.push(`${where}: not a valid ${def}: ${ajv.errorsText(validate.errors)}`);
  }
}

// 1. OpenAPI examples
const spec = read("api/openapi.bundled.json");
const post = spec.paths["/api/v1/sync/commands"].post;
const get = spec.paths["/api/v1/sync/changes"].get;
const request = post.requestBody.content["application/json"].example;
expectValid("command_batch", request, "post_sync_commands request example");
request.commands.forEach((command, i) => expectValid("command", command, `post_sync_commands request example /commands/${i}`));
expectValid("receipt_batch", post.responses["200"].content["application/json"].example, "post_sync_commands 200 example");
expectValid("changes_page", get.responses["200"].content["application/json"].example, "list_sync_changes 200 example");

// 2. custom_dhikr_validity
const document = schema("custom_dhikr_document");
for (const c of read("sync/v1/fixtures/custom_dhikr_validity.json").cases) {
  checks += 1;
  if (document(c.given.document) !== c.expect.valid) {
    problems.push(`custom_dhikr_validity "${c.id}": expect.valid is ${c.expect.valid} but the schema says ${!c.expect.valid}`);
  }
}

// 3. sync_receipts
for (const c of read("sync/v1/fixtures/sync_receipts.json").cases) {
  c.given.batch.forEach((command, i) => {
    const receipt = c.expect.receipts[i];
    const outcome = receipt.status === "duplicate" ? receipt.original : receipt;
    if (outcome.status !== "rejected") expectValid("command", command, `sync_receipts "${c.id}" /given/batch/${i}`);
  });
}

// 4. tag_name_normalization
for (const c of read("sync/v1/fixtures/tag_name_normalization.json").cases) {
  if (c.expect.accepted) {
    expectValid("user_tag_document", { name: c.expect.name, normalized_name: c.expect.normalized_name }, `tag_name_normalization "${c.id}"`);
  }
}

if (problems.length > 0) {
  for (const p of problems) console.error(p);
  process.exit(1);
}
console.log(`sync contract: ${checks} checks pass (OpenAPI examples, validity, receipts and tag names agree with sync.schema.json)`);
