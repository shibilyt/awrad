// Keeps the change-queue contract consistent with itself (contracts/sync/v1/README.md):
//   1. every example of the sync operations in api/openapi.bundled.json matches sync/v1/sync.schema.json, which
//      the OpenAPI restates (its bundler can't follow urn: references);
//   2. custom_dhikr_validity.json says "valid" exactly when the document matches $defs/custom_dhikr_document and
//      every Qur'an reference has ayah_end >= ayah_start (the one rule the schema can't express), and lists a
//      `range` error for each reversed reference;
//   3. every command in sync_receipts.json that isn't rejected is a valid $defs/command, with ordered Qur'an ranges;
//   4. every name tag_name_normalization.json accepts makes a valid $defs/user_tag_document;
//   5. in sync_receipts.json, an `applied` receipt (or a duplicate's original) has an array `cascaded` exactly when
//      its command is a user_tag or custom_dhikr delete (null otherwise), listing the other entities changed at that
//      revision, in changes-feed order, as the expected changes show them;
//   6. in sync_receipts.json, a custom_dhikr put naming uploaded audio is `applied` only when its asset_id is a ready
//      asset in the state's audio_assets, and `rejected` `audio_not_found` exactly when it isn't (with a `not_found`
//      error on /document/audio/asset_id); no other command is audio_not_found.
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

// Qur'an references whose ayah_end is below their ayah_start: `range` errors on ayah_end.
function rangeErrors(document) {
  const references = Array.isArray(document?.references) ? document.references : [];
  return references.flatMap((r, i) =>
    r?.type === "quran" && Number.isInteger(r.ayah_start) && Number.isInteger(r.ayah_end) && r.ayah_end < r.ayah_start
      ? [{ field: `/references/${i}/ayah_end`, code: "range" }]
      : [],
  );
}

// 2. custom_dhikr_validity
const document = schema("custom_dhikr_document");
for (const c of read("sync/v1/fixtures/custom_dhikr_validity.json").cases) {
  checks += 1;
  const ranges = rangeErrors(c.given.document);
  const valid = document(c.given.document) && ranges.length === 0;
  if (valid !== c.expect.valid) {
    problems.push(`custom_dhikr_validity "${c.id}": expect.valid is ${c.expect.valid} but the schema and range rule say ${valid}`);
  }
  for (const e of ranges) {
    if (!c.expect.errors.some((x) => x.field === e.field && x.code === e.code)) {
      problems.push(`custom_dhikr_validity "${c.id}": expect.errors lacks {"field": "${e.field}", "code": "range"}`);
    }
  }
  for (const e of c.expect.errors.filter((x) => x.code === "range")) {
    if (!ranges.some((x) => x.field === e.field)) {
      problems.push(`custom_dhikr_validity "${c.id}": ${e.field} isn't a reversed Qur'an range`);
    }
  }
}

// 3, 5 and 6. sync_receipts
const entityKey = (e) => `${e.entity_type} ${e.entity_id}`;
const assetOf = (command) =>
  command.entity_type === "custom_dhikr" && command.op === "put" && typeof command.document?.audio?.asset_id === "string"
    ? command.document.audio.asset_id
    : null;
for (const c of read("sync/v1/fixtures/sync_receipts.json").cases) {
  const ready = new Set(c.given.state.audio_assets.filter((a) => a.status === "ready").map((a) => a.asset_id));
  c.given.batch.forEach((command, i) => {
    const where = `sync_receipts "${c.id}" /expect/receipts/${i}`;
    const receipt = c.expect.receipts[i];
    const outcome = receipt.status === "duplicate" ? receipt.original : receipt;
    // 6. audio_not_found (a duplicate replays a decision made against an earlier state, so only fresh receipts count)
    if (receipt.status !== "duplicate") {
      checks += 1;
      const asset = assetOf(command);
      const audioRejected = outcome.status === "rejected" && outcome.code === "audio_not_found";
      if (audioRejected && (asset === null || ready.has(asset))) {
        problems.push(`${where}: audio_not_found, but the command names ${asset === null ? "no uploaded audio" : "a ready asset"}`);
      }
      if (audioRejected && JSON.stringify(outcome.fields) !== JSON.stringify([{ field: "/document/audio/asset_id", code: "not_found" }])) {
        problems.push(`${where}: audio_not_found carries fields [{"field": "/document/audio/asset_id", "code": "not_found"}]`);
      }
      if (outcome.status === "applied" && asset !== null && !ready.has(asset)) {
        problems.push(`${where}: applied, but ${asset} isn't a ready asset in given.state.audio_assets (audio_not_found)`);
      }
    }
    if (outcome.status !== "rejected") {
      expectValid("command", command, `sync_receipts "${c.id}" /given/batch/${i}`);
      if (command.entity_type === "custom_dhikr" && command.op === "put" && rangeErrors(command.document).length > 0) {
        problems.push(`sync_receipts "${c.id}" /given/batch/${i}: a reversed Qur'an range must be rejected`);
      }
    }
    if (outcome.status !== "applied") return;
    checks += 1;
    const cascades = command.op === "delete" && ["user_tag", "custom_dhikr"].includes(command.entity_type);
    if (!cascades) {
      if (outcome.cascaded !== null) problems.push(`${where}: cascaded is null unless the command is a user_tag or custom_dhikr delete`);
      return;
    }
    if (!Array.isArray(outcome.cascaded)) {
      problems.push(`${where}: an applied ${command.entity_type} delete must carry cascaded`);
      return;
    }
    const keys = outcome.cascaded.map(entityKey);
    if (keys.some((key, k) => k > 0 && keys[k - 1] >= key)) {
      problems.push(`${where}: cascaded isn't ordered by entity_type, then entity_id`);
    }
    const own = (e) => e.entity_type === command.entity_type && e.entity_id === command.entity_id;
    for (const entry of outcome.cascaded) {
      if (entry.revision !== outcome.revision) problems.push(`${where}: cascaded ${entityKey(entry)} isn't at the receipt's revision`);
      if (own(entry)) problems.push(`${where}: cascaded lists the command's own entity`);
    }
    // A duplicate replays a revision from before the batch, so only a fresh receipt is compared with the changes.
    if (receipt.status === "duplicate") return;
    for (const change of c.expect.changes.filter((e) => e.revision === outcome.revision && !own(e))) {
      const entry = outcome.cascaded.find((e) => entityKey(e) === entityKey(change));
      if (!entry) {
        problems.push(`${where}: cascaded lacks ${entityKey(change)}, changed at revision ${outcome.revision}`);
      } else if (entry.state !== change.state || entry.version !== change.version) {
        problems.push(`${where}: cascaded ${entityKey(change)} is ${entry.state} v${entry.version}, the change is ${change.state} v${change.version}`);
      }
    }
    for (const entry of outcome.cascaded) {
      const change = c.expect.changes.find((e) => entityKey(e) === entityKey(entry));
      if (!change || change.revision < outcome.revision) {
        problems.push(`${where}: cascaded ${entityKey(entry)} has no change at revision ${outcome.revision} or later`);
      }
    }
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
console.log(`sync contract: ${checks} checks pass (OpenAPI examples, validity and Qur'an ranges, receipts, cascades and audio_not_found, tag names agree with sync.schema.json)`);
