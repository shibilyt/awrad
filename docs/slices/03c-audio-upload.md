# Slice 3c: Private audio for custom dhikrs

Status: Done 2026-10-29
Plan entry: [`docs/rebuild-plan.md`](../rebuild-plan.md), slice 3c
Playbook: [`docs/slice-playbook.md`](../slice-playbook.md)

## Goal

A signed-in user's custom dhikr recording reaches every device and the web. A recording added on a phone uploads to private storage; their other devices and the web can play it. Signed out, recordings stay on the phone as in 3b.

## Decisions (2026-10-28 and 2026-10-29)

- **Upload only when signed in.** Signed out, audio stays on the phone (3b's `{"local_only": true}`).
- **Limits:**
  - 10,000,000 bytes per file;
  - 500,000,000 bytes per account (uploaded and pending together);
  - MP3 (`audio/mpeg`) and M4A/AAC (`audio/mp4`) only.
- **A private bucket,** `awrad-private-dhikr`, separate from the public built-in bucket (`dhikrs.awrad.app`):
  - no public access;
  - every read and write uses a short-lived signed link from the server;
  - CORS allows the web origin(s) to `PUT`, `GET` and `HEAD`, with the request headers `content-type` and `x-amz-checksum-sha256`.
- **Secrets:**
  - locally, `awrad-server-next/mise.local.toml` (ignored by git);
  - in production, Dokploy environment variables;
  - the variables are `AWRAD_R2_ACCOUNT_ID`, `AWRAD_R2_PRIVATE_BUCKET`, `AWRAD_R2_ACCESS_KEY_ID` and `AWRAD_R2_SECRET_ACCESS_KEY`.

## Scope

| In scope | Out of scope |
|---|---|
| Upload API: reserve an upload, upload directly to R2, confirm | Recording audio in the app (import only, as in 3b) |
| A custom dhikr document can point at an uploaded recording | Audio for built-in dhikrs (catalog, public bucket) |
| Playing an uploaded recording on other devices and the web, with an offline cache on phones | Transcoding, trimming, normalising |
| Storage used, shown in Settings ("120 MB of 500 MB") | Per-file sharing between accounts |
| Cleanup: replaced, deleted and abandoned recordings, and all of them on account deletion | |
| The web can add a recording to a custom dhikr | |

Platforms: server ☑ · Android ☑ · iOS ☑ · web ☑

## Design

### The recording in the custom dhikr document

`audio` is one of:
- `null`;
- `{"local_only": true}`, kept on the phone that imported it (3b);
- `{"asset_id": "<uuidv7>", "byte_size": 4182733, "content_type": "audio/mpeg", "duration_ms": 31250}`, an uploaded recording. `duration_ms` is optional: the client measures it, and the server doesn't decode audio.

A `put` that names an `asset_id` the account doesn't have as a confirmed upload is `rejected audio_not_found`.

### Uploading (REST, outside the change queue: the bytes don't go through sync)

1. **`POST /api/v1/audio_uploads`** with `{asset_id, byte_size, content_type, sha256}`. `asset_id` is a client-made UUIDv7, which makes the call idempotent.
   - The server checks the type, the size and the account's quota.
   - It records a pending upload and answers `201 {asset_id, upload_url, upload_headers, expires_at}`: a signed `PUT` link valid for 15 minutes.
   - The headers include `x-amz-checksum-sha256`, so R2 itself refuses bytes that don't match.
   - Errors: `413 file_too_large`, `415 unsupported_audio_type`, `422 storage_full` with `{used_bytes, limit_bytes}`.
2. **The client `PUT`s the file straight to R2** with those headers.
3. **`POST /api/v1/audio_uploads/{asset_id}/complete`.** The server checks the stored object's size, type and checksum, marks it ready, and answers `200 {asset}`. If the object is missing or wrong: `409 upload_incomplete`, or the server deletes it and answers `422 upload_mismatch`.
4. **The client queues the custom dhikr `put`** with the `asset_id`, through the change queue as usual.

### Playing

- **`GET /api/v1/audio_assets/{asset_id}/download`** returns `{url, expires_at}`, a signed `GET` link valid for 10 minutes, for the account's own ready assets only.
- **Phones** download a recording on first play into the active profile's files and play it from there afterwards, offline too. The cached file goes when the dhikr's audio changes or the dhikr is deleted.
- **The web** plays from the signed link.

### Storage used

`GET /api/v1/audio_assets/usage` returns `{used_bytes, limit_bytes}`. Settings shows it on phones and the web.

### Cleanup (server jobs)

- **Pending uploads** never confirmed within 24 hours: delete the object (if any) and the record.
- **Ready assets** that no active custom dhikr has referenced for 24 hours: delete them. That covers a replaced recording, a removed recording and a deleted dhikr. The 24 hours lets a queued edit referencing the asset still land.
- **Account deletion:** delete every object of the account.

### Phones

- **Importing audio:**
  - signed in and online: upload in the background and queue the `put` once it's confirmed;
  - offline, or not yet uploaded: the document keeps `{"local_only": true}`, and the upload runs once signed in and online.
- **"Add to my account"** (3b) uploads each local recording, then queues the dhikr.
- **A recording that can't upload** (over the quota, or a type mismatch) stays local, with a notice ("Audio couldn't be uploaded: storage full"). The dhikr still syncs without it.
- **Pending uploads persist** in the profile, alongside the change queue, and survive restarts.

### Web

The custom dhikr editor gets "Add audio" (MP3/M4A file picker, the same checks), the upload flow above, and the player bar from 3a.

## Domain and fixtures

- **`contracts/audio/v1/fixtures/audio_upload_validity.json`:** given `byte_size`, `content_type` and `used_bytes`, whether an upload is allowed or which error it gets. Clients pre-check with it and the server enforces it.
- **`sync/v1`:** `custom_dhikr_validity` gains cases for the uploaded-recording `audio` shape, and `sync_receipts` gains `rejected audio_not_found`.

## Contract

- **Operations:**
  - `create_audio_upload`: `POST /api/v1/audio_uploads`;
  - `complete_audio_upload`: `POST /api/v1/audio_uploads/{asset_id}/complete`;
  - `get_audio_download`: `GET /api/v1/audio_assets/{asset_id}/download`;
  - `get_audio_usage`: `GET /api/v1/audio_assets/usage`.
- **Auth:** bearer (mobile) or cookie plus CSRF (web), and `X-Awrad-Account`, as in 3b.
- **ADR:** user audio lives in a private R2 bucket, reached only by signed links.

## Platform work

| Project | Work | Validation | Status |
|---|---|---|---|
| awrad-server-next | Asset table, the four endpoints, R2 signing (SigV4) with a stand-in for tests, cleanup jobs, quota | `mix validate`, plus a real-bucket check | ☑ |
| awrad-android-next | Upload worker, the `local_only` → asset swap, the download cache, quota in Settings | Gradle validation | ☑ |
| awrad-ios-next | Same as Android | `scripts/validate` | ☑ |
| awrad-web-next | Add audio in the editor, upload, play, quota in Settings | `npm run validate` | ☑ |

## Integration evidence

| Flow | Android | iOS | Web |
|---|---|---|---|
| Add audio while signed in; it plays on another device | ☑ | ☑ | ☑ |
| Add audio offline, then sign in and Add to my account; it uploads | ☑ | ☑ | — |
| An 11 MB file and an over-quota upload are refused clearly | ☑ | ☑ | ☑ |
| Replace or remove a recording; the old object is cleaned up after 24 hours (the job runs on demand in tests) | ☑ | ☑ | ☑ |
| Play an uploaded recording offline after the first play | ☑ | ☑ | — |

Evidence (2026-10-29), against the real server and the private R2 bucket:
- **API run:** 18 of 18 checks pass: signed `PUT` with R2 refusing altered bytes, confirm, `audio_mismatch`, `audio_not_found`, a second device downloading identical bytes, 413, 415, `storage_full` and usage.
- **Android emulator:** 5 of 5 flows.
- **iOS simulator:** 4 of 4, after fixing a percent-encoded path bug that hid every file under `Application Support`.
- **Web in the browser** on port 5180 (CORS): upload, play, the 10 MB and type refusals, and the storage card.
- **Cleanup timing** is covered by server tests with a moved clock.
