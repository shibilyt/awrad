# Wird model v1

This directory owns the reviewed, cross-platform bundled Wird definition format.

- `wird-model.schema.json` documents the portable asset shape.
- `fixtures/dalail-al-khayrat.json` is the canonical devotional-content source.
- `fixtures/behavior.json` locks the Android v5 cadence, counts, content hash, and representative structural IDs.
- `manifest.json` is generated and enumerates every deterministic Wird, part, and segment ID.

Run `./scripts/generate_wird_model.py` after an intentional canonical-content change. Run
`./scripts/generate_wird_model.py --check` in validation to reject stale Android or iOS assets.

Structural IDs use the same UUIDv3 algorithm as Java `UUID.nameUUIDFromBytes` over the UTF-8 bytes
of `awrad-wird:<structural-path>`. The Wird path is its slug, part paths append `/part/<index>`, and
segment paths append `/seg/<index>`.

## Compatibility note

The previous iOS version-2 seed assigned random part and segment IDs. Its seven parts contain 12
segments, and none has an exact normalized content signature in this version-5 definition. Automatic
progress remapping is therefore unsafe. Before shipping the generated asset to an existing install,
the persistence migration must keep each incomplete version-2 session pinned to its legacy definition
or postpone replacement until no such sessions remain. Replacing the seed directly would leave the
session's part and segment references orphaned.
