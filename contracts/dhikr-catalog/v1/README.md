# Dhikr catalog v1

The single source of truth for Awrad's **built-in dhikrs** and the **collections** that list them. Android, iOS, the server and the web app generate their built-in content from [`catalog.json`](catalog.json) at build time. They don't keep hand copies, which is how the frozen apps drifted (see [`SOURCES.md`](SOURCES.md)).

| File | What it is |
|---|---|
| `catalog.json` | 113 dhikrs (13 hand-written plus the 100 Asma-ul Husna names) and 5 collections |
| `dhikr-catalog.schema.json` | JSON Schema 2020-12 (`urn:awrad:dhikr-catalog:1`); `$defs/dhikr` is the dhikr shape, for reuse by custom dhikrs |
| `SOURCES.md` | Where each field came from, the disagreements between the frozen copies, and what needs human or scholar review |

## A dhikr

A dhikr is one text, recited as a unit. It has no parts, sequences, occasions or recommended counts; practices and wirds will hold those.

| Field | Meaning |
|---|---|
| `id`, `key` | Immutable identity (below) |
| `kind` | `quran`, `dhikr`, `dua`, `salawat` or `name_of_allah`. It drives rendering. |
| `arabic` | The text as recited, with harakat. Qur'an goes one ayah per line, with no ayah numbers (`(1)`) or decorative separators (`❁`). Apps add those when displaying. |
| `title` | `{en, ar, ml}`, all required |
| `transliteration` | One per language, in that language's script: `en` is Latin (required), `ml` is Malayalam script. Arabic has none. |
| `aliases` | Optional extra search terms per language (`{en?: […], ar?: […], ml?: […]}`): spelling variants and common names people type. Each is in its language's script and doesn't repeat the title or transliteration. Not shown as text. |
| `translation` | `{en, ar?, ml?}` |
| `audio` | `null` or one recording. `url` is the full link to the file in the Awrad Cloudflare R2 bucket, served at `https://dhikrs.awrad.app/` (the frozen Android app's links), `style` is `recitation`, `melodic` or `teaching`, and `repetitions` is how many recitations one play contains. Optional: `reciter`, `durationMs`, `byteSize`, `mimeType`, `sha256`, `attribution`. |
| `references` | Sources, each with an `id` unique within the dhikr and a `type`: `quran` (surah, ayah range), `hadith` (collection, number, narrator, grade), `book`, `shaykh` or `other`. A `quran`-kind dhikr must cite the Qur'an. |
| `virtues` | `{text: {en, ar?, ml?}, references: [id, …]}`. Every virtue cites at least one of the dhikr's references. A benefit with no source isn't a virtue; it waits in `SOURCES.md` until it has one. |

## Identity

- `key` and `id` are the existing catalog-key/UUIDv4 pairs from [`../../progress-model/v1/builtin-dhikrs.json`](../../progress-model/v1/builtin-dhikrs.json) (ADR-2026-07-13). They never change, not even to fix a spelling (`isthighfar` stays), because users' goals and counts point at them.
- Every pair in the registry is in the catalog, and nothing else is. The checker enforces this both ways.
- **Adding a dhikr:** add its pair to `builtin-dhikrs.json` and the dhikr here, in the same change.
- **Removing a dhikr** must never delete its identity, because progress may refer to it. Removal needs a `status` (for example `retired`), like the registry's. The catalog doesn't have one yet; add it when the first removal happens.

## Collections

Categories are gone. A collection is an ordered list of dhikr keys with a localized title (`{en, ar, ml}`), and a dhikr may appear in several. Every dhikr is in at least one collection, and empty collections aren't allowed.

| Key | Contents |
|---|---|
| `daily-essentials` | tahleel, ya-wahhabu, isthighfar, surah-ikhlas |
| `dhikrs` | tahleel, ya-wahhabu, isthighfar |
| `swalaths` | the 6 salawat |
| `ramadan` | the 3 Ramadan dhikrs |
| `asma-ul-husna` | the 100 names, in number order (Allah first) |

Morning, evening and after-prayer collections will be added when that content exists.

## Asma-ul Husna

The names come from [`../../progress-model/v1/asma-ul-husna.json`](../../progress-model/v1/asma-ul-husna.json), which this catalog **supersedes** as the content source. That file stays because the frozen-era generator and validators read it.

Each name is a `name_of_allah` dhikr in its **invocation form**, as the native apps show it: `arabic` is `يَا رَحْمَٰنُ` and `transliteration.en` is `Ya Rahman` (the `invocation_*` fields made by `scripts/generate_asma_ul_husna.py`). The plain name appears as `title.ar` (`ٱلرَّحْمَٰنُ`); en and ml titles use the invocation transliteration. Aliases carry the plain name (`Ar-Rahman`, `Rahman`). A name's number is its position in the `asma-ul-husna` collection. Translations are en only: there is no Malayalam meaning yet, and none will be machine-translated.

## Languages and fallback

- `title` (dhikrs and collections) requires `en`, `ar` and `ml`.
- `translation`, virtue `text` and `transliteration` require `en`. When `ar` or `ml` is missing, apps show `en`.
- The checker prints the missing ar/ml counts on every run, so the gap stays visible. Missing translations aren't failures. Don't fill them with machine translation.

## contentRevision

`contentRevision` is an integer. Bump it by one in any change that alters what users see: text, titles, translations, virtues, references, audio, or collection membership and order. Apps store the revision of the built-in content they last applied and refresh it when the generated revision is higher. The revision never touches identity or user data. `version` changes only when the shape changes incompatibly.

## Checks

`npm test` in `contracts/` runs `tools/check-dhikr-catalog.mjs`. It checks:

- the schema;
- key/id parity with `builtin-dhikrs.json`;
- that keys and ids are unique;
- that collection references resolve, with no duplicates within a collection;
- that every dhikr is in a collection;
- that reference ids are unique within a dhikr and virtue references resolve;
- that `quran`-kind dhikrs cite the Qur'an;
- that Arabic fields are Arabic script and recited text has no Latin letters, ayah numbers or separators;
- that each transliteration and alias is in its language's script, and no alias repeats the title or transliteration;
- that Qur'an ranges fall within the surah.

It also prints the missing-translation counts. Run `node tools/check-dhikr-catalog.mjs <file>` to check a different file.
