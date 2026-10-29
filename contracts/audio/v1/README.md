# Audio v1: private recordings for custom dhikrs

How a signed-in user's own recording reaches their other devices and the web. Slice 3c ([brief](../../../docs/slices/03c-audio-upload.md)) builds it. Decision: root [`DECISIONS.md`](../../../DECISIONS.md) ADR-2026-10-29 "User audio lives in a private bucket reached only by signed links".

| File | What it is |
|---|---|
| `audio.schema.json` | JSON Schema 2020-12, `urn:awrad:audio:1`: the upload request and its answer, an asset, a download link, storage used, and the limits |
| `fixtures/audio_upload_validity.json` | `awrad-fixture/1`: whether an upload is allowed, or which error it gets |
| [`../../api/paths/audio.yaml`](../../api/paths/audio.yaml) | The four HTTP operations. Their schemas restate this one, because the OpenAPI bundler can't follow `urn:` references; `tools/check-audio-contract.mjs` checks every example against `audio.schema.json` |
| [`../../sync/v1/`](../../sync/v1/) | The custom dhikr document's `audio` member, which names an uploaded recording (`$defs/uploaded_audio`), and the `audio_not_found` rejection |

Signed out, nothing here applies: a recording stays on the phone as `{"local_only": true}` (slice 3b), and the app makes no API call.

## Limits

| Limit | Value |
|---|---|
| Per file | 1 to 10,000,000 bytes (10 MB, decimal: 10 MiB is too large) |
| Per account | 500,000,000 bytes, ready assets and pending uploads together |
| Types | `audio/mpeg` (MP3) and `audio/mp4` (M4A/AAC), exactly as written: lowercase, no parameters. `AUDIO/MPEG`, `audio/x-m4a`, `audio/mp3` and `audio/wav` are refused |

The checks run in this order, and the first failure answers ([`fixtures/audio_upload_validity.json`](fixtures/audio_upload_validity.json)):

1. the type: `unsupported_audio_type` (`415`);
2. the size: below 1 is `invalid_size` (`422`), above 10,000,000 is `file_too_large` (`413`);
3. the quota: `used_bytes + byte_size` above 500,000,000 is `storage_full` (`422`, with `used_bytes` and `limit_bytes` in the problem). Exactly 500,000,000 is allowed.

Clients run the same rules before asking, with `used_bytes` from `get_audio_usage`; the server enforces them. A file that is too large is refused before the quota is looked at, so the user isn't told to free space that wouldn't help.

**Media types on import.** Clients map the file to one of the two types themselves (an `.mp3` is `audio/mpeg`; an `.m4a`, or a system type such as `audio/x-m4a`, is `audio/mp4`), and refuse anything else before uploading. The server compares strings only; it never decodes audio, so `duration_ms` is the client's measurement.

## Uploading

The bytes go straight between the client and storage; they never pass through the API or the change queue.

1. **Reserve: `POST /api/v1/audio_uploads`** (`create_audio_upload`) with `{asset_id, byte_size, content_type, sha256}`.
   - `asset_id` is a new UUIDv7 made by the client for this recording; `sha256` is the file's SHA-256 in 64 lowercase hex digits.
   - The server checks the rules above, records a **pending upload**, and answers `201 {asset_id, upload_url, upload_headers, expires_at}`: a signed `PUT` link valid for **15 minutes**.
   - `upload_headers` holds `content-type` and `x-amz-checksum-sha256` (the same SHA-256, base64). The link is signed with both, so R2 refuses a different type or different bytes.
   - **Repeats are idempotent by `asset_id`:**
     - the same body while still pending is `200` with a fresh link, and doesn't count against the quota twice;
     - the same body once ready is `200 {asset}`: skip the PUT and the completion;
     - a different body, or an ID another account uses, is `409 asset_id_in_use`.
2. **PUT the file to `upload_url`**, unchanged, with every header in `upload_headers` exactly as given. Clients treat the link and the header map as opaque. If the link has expired, reserve again with the same body for a fresh one.
3. **Confirm: `POST /api/v1/audio_uploads/{asset_id}/complete`** (`complete_audio_upload`), no body.
   - The server reads the stored object's size, content type and checksum, and compares them with the upload's.
   - They match: the upload becomes a **ready asset**, `200 {asset}` (`{asset_id, byte_size, content_type, status: "ready", created_at}`). Completing a ready asset again returns it again.
   - No object yet: `409 upload_incomplete`. PUT again, then confirm again.
   - A mismatch: the server deletes the object and the pending upload, and answers `422 upload_mismatch`. The recording stays local; a retry starts over with a new `asset_id`.
   - An unknown `asset_id`, another account's, or one already cleaned up: `404`.
4. **Point the dhikr at it.** The client queues the custom dhikr `put` whose `audio` is `{asset_id, byte_size, content_type, duration_ms}`, through the change queue as usual. `byte_size` and `content_type` are copied from the asset. A put naming an `asset_id` that isn't a ready asset of the account is `rejected` with `audio_not_found`; one whose `byte_size` or `content_type` isn't the asset's is `rejected` with `audio_mismatch` ([`sync_receipts.json`](../../sync/v1/fixtures/sync_receipts.json)). So a client always completes the upload before it queues the put.

## Playing

- **`GET /api/v1/audio_assets/{asset_id}/download`** (`get_audio_download`) returns `{url, expires_at}`: a signed `GET` link valid for **10 minutes**, for the account's own ready assets only. Anything else (unknown, pending, another account's, cleaned up) is `404`. Ask for a link when playback starts; don't store one.
- **Phones** download a recording on its first play into the active profile's files, and play it from there afterwards, offline too. The cached file goes when the dhikr's `audio` changes or the dhikr is deleted, and with its profile.
- **The web** plays from the signed link. The bucket's CORS allows the web origin(s) to `PUT`, `GET` and `HEAD`.

## Storage used

**`GET /api/v1/audio_assets/usage`** (`get_audio_usage`) returns `{used_bytes, limit_bytes}`. `used_bytes` counts ready assets and pending uploads by their declared `byte_size`. Settings shows it on phones and the web ("120 MB of 500 MB", in decimal megabytes to match the limits).

## Cleanup (server jobs)

| What | When | What goes |
|---|---|---|
| A pending upload never confirmed | 24 hours after it was reserved | Its object (if any) and its record |
| A ready asset no active custom dhikr references | After 24 hours unreferenced | Its object and its record. Covers a replaced recording, a removed recording and a deleted dhikr. The 24 hours let a queued edit that still names the asset land |
| Everything of an account | When the account is deleted | Every object and record |

A cleaned-up `asset_id` is gone for good: a put naming it is `audio_not_found`, and a download is `404`. Clients never reuse an `asset_id` for a different file.

## Both kinds of client

- **Auth.** A bearer token (phones) or the browser cookie session; the two POSTs also need `X-CSRF-Token`.
- **`X-Awrad-Account`** is required on all four, as on the change queue: a different account is `409 account_mismatch`, with nothing read or written; a missing or malformed header is `400`.
- **Errors.** `401`, `403` (CSRF) and `429` with `Retry-After` as on other authenticated routes. A body that breaks the request schema (a non-UUID `asset_id`, a malformed `sha256`, a negative `byte_size`, an unknown member) is `400 malformed_request`.
- **`Idempotency-Key`** is accepted and ignored on the POSTs: reserving is idempotent by `asset_id`, and confirming is idempotent anyway.
- Every response is `Cache-Control: no-store`.

## Phones

- **Importing audio** while signed in and online uploads in the background, then queues the `put` once the upload is confirmed. Offline, or not uploaded yet, the document keeps `{"local_only": true}`, and the upload runs once signed in and online.
- **"Add to my account"** (slice 3b) uploads each local recording, then queues its dhikr.
- **A recording that can't upload** (`storage_full`, `file_too_large`, `unsupported_audio_type`, `invalid_size`, `upload_mismatch`) stays local, with a notice ("Audio couldn't be uploaded: storage full"). The dhikr still syncs, with `{"local_only": true}`.
- **Pending uploads persist** in the profile, alongside the change queue, and survive restarts.
- **An `audio_not_found` or `audio_mismatch` rejection loses nothing** ([`apply_changes.json`](../../sync/v1/fixtures/apply_changes.json); sync README, "Sending and pulling"). The phone keeps its local document. If the recording's file is still on the phone, `audio` goes back to `{"local_only": true}` and the upload is queued again under a new `asset_id`; otherwise `audio` becomes `null`. Either way a put of the kept document is queued on the server's version, ahead of other unsent commands, and the user gets a notice.

## Fixtures

| File | Who runs it | Cases |
|---|---|---|
| `audio_upload_validity.json` | All four | `byte_size`, `content_type` and `used_bytes`: allowed, or the error |

The sync fixtures cover the rest: `custom_dhikr_validity` (the document's `audio` shape), `sync_receipts` (`audio_not_found`, `audio_mismatch`) and `apply_changes` (phones keeping an audio-rejected edit).

`npm test` in `contracts/` validates the fixture and runs `tools/check-audio-contract.mjs`. That script checks that:
- the OpenAPI examples match `audio.schema.json`, and a reserved upload's headers carry the request's type and its SHA-256 in base64;
- the OpenAPI restatements keep the schema's limits and members;
- each upload error has its HTTP status and an example on `create_audio_upload`;
- every fixture case agrees with the rules, computed from the schema's limits;
- the fixture covers both sides of each limit, case and alias variants of the type, and every precedence pair.
