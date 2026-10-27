# Progress model v1

The progress model's schema, field ownership and fixtures (ADR-2026-07-13).

- `builtin-dhikrs.json`: the immutable catalog-key/UUIDv4 pairs of the 113 built-in dhikrs. This is still the identity registry; [`../../dhikr-catalog/v1/catalog.json`](../../dhikr-catalog/v1/catalog.json) must match it exactly.
- `asma-ul-husna.json`: **superseded as a content source** by [`../../dhikr-catalog/v1/`](../../dhikr-catalog/v1/README.md), which now owns the names, meanings, invocation forms and collection order. It is kept unchanged because the frozen-era generator (`scripts/generate_asma_ul_husna.py`) and validators read it. Don't edit it to change content; edit the catalog.
