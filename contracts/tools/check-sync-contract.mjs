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
//      asset in the state's audio_assets with the same byte_size and content_type; `audio_not_found` only when it
//      isn't ready (a `not_found` error on /document/audio/asset_id); `audio_mismatch` only when it is ready but
//      disagrees (a `mismatch` error on each disagreeing member, sorted); no other command gets either code;
//   7. in apply_changes.json, an audio_not_found or audio_mismatch rejection of a custom_dhikr put loses nothing: the
//      phone keeps its document with audio {"local_only": true} (file still on the phone: the upload is queued again)
//      or null, takes the server's version, replaces the entity's unsent commands with one put of that document (or
//      a delete if the phone deleted it since) ahead of every other unsent command, and adds a notice; no other step
//      queues an upload.
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
const AUDIO_CODES = ["audio_not_found", "audio_mismatch"];
// What the server decides about a put's uploaded audio: null when it names a matching ready asset (or no upload).
function audioVerdict(command, assets) {
  const asset = assetOf(command);
  if (asset === null) return null;
  const ready = assets.find((a) => a.asset_id === asset && a.status === "ready");
  if (!ready) return { code: "audio_not_found", fields: [{ field: "/document/audio/asset_id", code: "not_found" }] };
  const fields = ["byte_size", "content_type"]
    .filter((member) => command.document.audio[member] !== ready[member])
    .map((member) => ({ field: `/document/audio/${member}`, code: "mismatch" }));
  return fields.length > 0 ? { code: "audio_mismatch", fields } : null;
}
for (const c of read("sync/v1/fixtures/sync_receipts.json").cases) {
  c.given.batch.forEach((command, i) => {
    const where = `sync_receipts "${c.id}" /expect/receipts/${i}`;
    const receipt = c.expect.receipts[i];
    const outcome = receipt.status === "duplicate" ? receipt.original : receipt;
    // 6. audio checks (a duplicate replays a decision made against an earlier state, so only fresh receipts count)
    if (receipt.status !== "duplicate") {
      checks += 1;
      const verdict = audioVerdict(command, c.given.state.audio_assets);
      const audioRejected = outcome.status === "rejected" && AUDIO_CODES.includes(outcome.code);
      if (audioRejected && verdict?.code !== outcome.code) {
        problems.push(`${where}: ${outcome.code}, but the audio rule says ${verdict?.code ?? "the audio is fine"}`);
      } else if (audioRejected && JSON.stringify(outcome.fields) !== JSON.stringify(verdict.fields)) {
        problems.push(`${where}: ${outcome.code} carries fields ${JSON.stringify(verdict.fields)}`);
      }
      if (outcome.status === "applied" && verdict !== null) {
        problems.push(`${where}: applied, but the audio rule says ${verdict.code} against given.state.audio_assets`);
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

// 7. apply_changes: audio rejections keep local data
const sameJson = (a, b) => JSON.stringify(a) === JSON.stringify(b);
for (const c of read("sync/v1/fixtures/apply_changes.json").cases) {
  const where = `apply_changes "${c.id}"`;
  const queuedUploads = [];
  if (c.given.step.kind === "receipts") {
    const sent = c.given.local.outbox.filter((command) => command.sent);
    const unsentBefore = c.given.local.outbox.filter((command) => !command.sent).map((command) => command.command_id);
    let fresh = [...c.given.step.new_command_ids];
    c.given.step.receipts.forEach((receipt, i) => {
      const outcome = receipt.status === "duplicate" ? receipt.original : receipt;
      const command = sent[i];
      if (!(outcome.status === "rejected" && AUDIO_CODES.includes(outcome.code))) return;
      if (!(command?.entity_type === "custom_dhikr" && command.op === "put")) return;
      checks += 1;
      const id = command.entity_id;
      const mine = (e) => e.entity_type === "custom_dhikr" && e.entity_id === id;
      const version = outcome.current?.version ?? 0;
      const before = c.given.local.entities.find(mine);
      const after = c.expect.local.entities.find(mine);
      const queued = c.expect.local.outbox.filter(mine);
      if (!c.expect.notices.some((n) => mine(n) && n.code === outcome.code)) problems.push(`${where}: no ${outcome.code} notice for ${id}`);
      if (before) {
        const hasFile = c.given.local_audio_files.includes(id);
        const document = { ...before.document, audio: hasFile ? { local_only: true } : null };
        if (!after) {
          problems.push(`${where}: ${outcome.code} must not remove ${id}`);
          return;
        }
        if (!sameJson(after.document, document)) problems.push(`${where}: ${id} keeps its local document with audio ${JSON.stringify(document.audio)}`);
        if (after.known_version !== version) problems.push(`${where}: ${id} takes the server's version ${version}`);
        if (hasFile) queuedUploads.push(id);
        const put = queued[0];
        if (queued.length !== 1 || put.op !== "put" || put.base_version !== version || put.sent || !sameJson(put.document, document)) {
          problems.push(`${where}: ${id}'s unsent commands become one unsent put of the kept document on version ${version}`);
        }
      } else if (outcome.current === null ? queued.length !== 0 : queued.length !== 1 || queued[0].op !== "delete" || queued[0].base_version !== version) {
        problems.push(`${where}: ${id}, deleted on the phone since, ${outcome.current === null ? "queues nothing" : `queues one delete on version ${version}`}`);
      }
      if (queued.length === 1) {
        if (queued[0].command_id !== fresh[0]) problems.push(`${where}: the command queued for ${id} takes the next new_command_ids entry`);
        fresh = fresh.slice(1);
        const position = c.expect.local.outbox.indexOf(queued[0]);
        const overtaken = c.expect.local.outbox.slice(0, position).filter((x) => unsentBefore.includes(x.command_id) && !mine(x));
        if (overtaken.length > 0) problems.push(`${where}: the command queued for ${id} goes ahead of the other unsent commands`);
      }
    });
  }
  checks += 1;
  if (!sameJson(c.expect.uploads_queued, queuedUploads.sort())) {
    problems.push(`${where}: uploads_queued should be ${JSON.stringify(queuedUploads)} (recordings of audio-rejected puts whose file is on the phone)`);
  }
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
console.log(`sync contract: ${checks} checks pass (OpenAPI examples, validity and Qur'an ranges, receipts, cascades and audio checks, phones keeping audio-rejected edits, tag names agree with sync.schema.json)`);
