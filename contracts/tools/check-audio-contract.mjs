// Keeps the private-audio contract consistent with itself (contracts/audio/v1/README.md):
//   1. every example of the audio operations in api/openapi.bundled.json matches audio/v1/audio.schema.json, which
//      the OpenAPI restates (its bundler can't follow urn: references), and a reserved upload's headers carry the
//      request's content_type and its sha256 in base64;
//   2. the OpenAPI restatements keep the schema's limits: content types, byte_size bounds, the sha256 pattern and
//      the members of an uploaded recording;
//   3. each upload error has its HTTP status (415, 422, 413, 422) on create_audio_upload, with an example;
//   4. audio_upload_validity.json says exactly what the rules say, computed from the schema's limits: type, then
//      size, then quota;
//   5. audio_upload_validity.json covers the boundaries: both sides of the size and quota limits, case and alias
//      variants of the type, and every precedence pair.
// Usage: node tools/check-audio-contract.mjs
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { newAjv } from "./check-fixtures.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const read = (path) => JSON.parse(readFileSync(join(root, path), "utf8"));
const ajv = newAjv();
const schema = (def) => ajv.getSchema(`urn:awrad:audio:1#/$defs/${def}`);
const defs = read("audio/v1/audio.schema.json").$defs;
const problems = [];
let checks = 0;

function expectValid(def, value, where) {
  checks += 1;
  const validate = schema(def);
  if (!validate(value)) problems.push(`${where}: not a valid ${def}: ${ajv.errorsText(validate.errors)}`);
}

// 1. OpenAPI examples
const spec = read("api/openapi.bundled.json");
const create = spec.paths["/api/v1/audio_uploads"].post;
const complete = spec.paths["/api/v1/audio_uploads/{asset_id}/complete"].post;
const download = spec.paths["/api/v1/audio_assets/{asset_id}/download"].get;
const usage = spec.paths["/api/v1/audio_assets/usage"].get;
const json = (response) => response.content["application/json"];
const problem = (response) => response.content["application/problem+json"];
const examplesOf = (media) => (media.example !== undefined ? [["example", media.example]] : Object.entries(media.examples ?? {}).map(([k, e]) => [k, e.value]));

const request = create.requestBody.content["application/json"].example;
expectValid("upload_request", request, "create_audio_upload request example");
const created = json(create.responses["201"]).example;
expectValid("upload", created, "create_audio_upload 201 example");
for (const [name, value] of examplesOf(json(create.responses["200"]))) {
  expectValid("create_response", value, `create_audio_upload 200 example ${name}`);
}
for (const [name, value] of examplesOf(json(complete.responses["200"]))) {
  expectValid("asset_response", value, `complete_audio_upload 200 example ${name}`);
}
expectValid("download", json(download.responses["200"]).example, "get_audio_download 200 example");
expectValid("usage", json(usage.responses["200"]).example, "get_audio_usage 200 example");
checks += 1;
if (created.asset_id !== request.asset_id) problems.push("create_audio_upload 201 example: asset_id isn't the request's");
if (created.upload_headers["content-type"] !== request.content_type) {
  problems.push("create_audio_upload 201 example: upload_headers content-type isn't the request's content_type");
}
const base64 = Buffer.from(request.sha256, "hex").toString("base64");
if (created.upload_headers["x-amz-checksum-sha256"] !== base64) {
  problems.push(`create_audio_upload 201 example: x-amz-checksum-sha256 should be ${base64}, the request's sha256 in base64`);
}

// 2. OpenAPI restatements
const components = spec.components.schemas;
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const restated = [
  ["AudioContentType consts", components.AudioContentType.oneOf.map((s) => s.const), defs.content_type.enum],
  ["AudioByteSize bounds", [components.AudioByteSize.minimum, components.AudioByteSize.maximum], [defs.byte_size.minimum, defs.byte_size.maximum]],
  ["Sha256 pattern", components.Sha256.pattern, defs.sha256.pattern],
  ["AudioAsset members", components.AudioAsset.required, defs.asset.required],
  ["AudioUpload members", components.AudioUpload.required, defs.upload.required],
  ["AudioUpload upload_headers", components.AudioUpload.properties.upload_headers.required, defs.upload_headers.required],
  ["UploadedAudio members", components.UploadedAudio.required, read("sync/v1/sync.schema.json").$defs.uploaded_audio.required],
];
for (const [what, openapi, contract] of restated) {
  checks += 1;
  if (!same(openapi, contract)) problems.push(`OpenAPI ${what} ${JSON.stringify(openapi)} differ from the contract's ${JSON.stringify(contract)}`);
}

// 3. Upload errors on create_audio_upload
const statusOf = { unsupported_audio_type: "415", invalid_size: "422", file_too_large: "413", storage_full: "422" };
checks += 1;
if (!same(Object.keys(statusOf).sort(), [...defs.upload_error.enum].sort())) {
  problems.push(`upload_error ${JSON.stringify(defs.upload_error.enum)} isn't the set this checker maps to statuses`);
}
for (const [code, status] of Object.entries(statusOf)) {
  checks += 1;
  if (!create["x-error-codes"].includes(code)) problems.push(`create_audio_upload x-error-codes lacks ${code}`);
  const response = create.responses[status];
  const example = response && examplesOf(problem(response)).find(([, value]) => value.code === code)?.[1];
  if (!example) {
    problems.push(`create_audio_upload ${status} has no ${code} example`);
  } else if (example.status !== Number(status) || example.type !== `urn:awrad:problem:${code}`) {
    problems.push(`create_audio_upload ${status} ${code} example has the wrong status or type`);
  } else if (code === "storage_full") {
    expectValid("storage_full_problem", example, "create_audio_upload 422 storage_full example");
  }
}

// 4. audio_upload_validity agrees with the rules
const LIMIT = defs.account_limit_bytes.const;
const MIN = defs.byte_size.minimum;
const MAX = defs.byte_size.maximum;
function decide({ byte_size, content_type, used_bytes }) {
  if (!defs.content_type.enum.includes(content_type)) return "unsupported_audio_type";
  if (byte_size < MIN) return "invalid_size";
  if (byte_size > MAX) return "file_too_large";
  if (used_bytes + byte_size > LIMIT) return "storage_full";
  return null;
}
const fixture = read("audio/v1/fixtures/audio_upload_validity.json");
for (const c of fixture.cases) {
  checks += 1;
  const error = decide(c.given);
  if (c.expect.allowed !== (error === null) || c.expect.error !== error) {
    problems.push(`audio_upload_validity "${c.id}": expects ${JSON.stringify(c.expect)} but the rules say ${JSON.stringify({ allowed: error === null, error })}`);
  }
}

// 5. Boundary coverage
const fits = (g) => g.used_bytes + g.byte_size <= LIMIT;
const required = {
  "byte_size at the maximum, allowed": (g, e) => g.byte_size === MAX && e.allowed,
  "byte_size one above the maximum": (g, e) => g.byte_size === MAX + 1 && e.error === "file_too_large",
  "byte_size at the minimum, allowed": (g, e) => g.byte_size === MIN && e.allowed,
  "byte_size one below the minimum": (g, e) => g.byte_size === MIN - 1 && e.error === "invalid_size",
  "used + size exactly at the limit, allowed": (g, e) => g.used_bytes + g.byte_size === LIMIT && e.allowed,
  "used + size one above the limit": (g, e) => g.used_bytes + g.byte_size === LIMIT + 1 && e.error === "storage_full",
  "an upper-case allowed type": (g) => defs.content_type.enum.includes(g.content_type.toLowerCase()) && g.content_type !== g.content_type.toLowerCase(),
  "audio/x-m4a": (g) => g.content_type === "audio/x-m4a",
  "audio/wav": (g) => g.content_type === "audio/wav",
  "type before size": (g, e) => e.error === "unsupported_audio_type" && g.byte_size > MAX,
  "type before invalid_size": (g, e) => e.error === "unsupported_audio_type" && g.byte_size < MIN,
  "type before quota": (g, e) => e.error === "unsupported_audio_type" && g.byte_size >= MIN && g.byte_size <= MAX && !fits(g),
  "size before quota": (g, e) => e.error === "file_too_large" && g.used_bytes + MIN > LIMIT,
  "invalid_size before quota": (g, e) => e.error === "invalid_size" && g.used_bytes > LIMIT,
};
for (const [what, matches] of Object.entries(required)) {
  checks += 1;
  if (!fixture.cases.some((c) => matches(c.given, c.expect))) problems.push(`audio_upload_validity has no case for: ${what}`);
}
for (const type of defs.content_type.enum) {
  checks += 1;
  if (!fixture.cases.some((c) => c.given.content_type === type && c.expect.allowed)) {
    problems.push(`audio_upload_validity has no allowed case for ${type}`);
  }
}

if (problems.length > 0) {
  for (const p of problems) console.error(p);
  process.exit(1);
}
console.log(
  `audio contract: ${checks} checks pass (OpenAPI examples and restatements agree with audio.schema.json; ${fixture.cases.length} upload-validity cases follow the rules and cover the boundaries)`,
);
