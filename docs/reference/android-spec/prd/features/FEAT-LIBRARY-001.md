# FEAT-LIBRARY-001 — Dhikr library and discovery

**Status:** local bundled/user content.  
**Screens:** Library, Collection, Category, Dhikr Detail.

## Goal

Help a user find a dhikr by browsing local collections/categories or searching the available catalog, then open its detail or practice flow.

## Requirements

- **LIB-001 [OBSERVED]** Library is a bottom-navigation root.
- **LIB-002 [OBSERVED]** Browse the locally bundled dhikr catalog and featured/curated collections; open collection and category destinations.
- **LIB-003 [OBSERVED]** Open dhikr detail and provide routes to goal creation, audio preview where metadata exists, custom-dhikr actions, and Quran reader when available.
- **LIB-004 [OBSERVED]** User/custom content and tag/category assignments are local Room data; some supported custom-dhikr records may synchronize for authenticated accounts.
- **LIB-005 [OBSERVED]** Stable built-in identity is the catalog key/UUID pair; titles, Arabic text, transliteration, order, and audio URL are content, not identity.
- **LIB-006 [OBSERVED]** Built-in catalog content is shipped with the application; ordinary browse/detail does not require network access.
- **LIB-007 [UNKNOWN]** Exact search normalization, ranking, sorting, and no-result copy should follow current source before recreation.

## Acceptance examples

1. Bundled dhikr can be browsed in airplane mode.
2. A detail action passes the selected dhikr identity into goal creation.
3. A custom tag filter does not mutate the source dhikr or lose category assignments.
4. Catalog text/audio updates preserve the immutable catalog identity.

## Open decisions

Confirm whether collection order is editorial, category filters combine with AND, and whether user search should span Arabic, transliteration, and translation fields. Current behavior-model fixtures cover custom tag normalization/filter semantics where implemented.

