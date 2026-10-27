# Slice 3a: Dhikr catalog and library

Status: Draft
Plan entry: [`docs/rebuild-plan.md`](../rebuild-plan.md), slice 3a
Playbook: [`docs/slice-playbook.md`](../slice-playbook.md)

## Goal

Users can browse, search and read the built-in dhikrs and listen to their audio, in their own language, on Android, iOS and the web. Every app gets its content from one shared catalog instead of drifted hand copies.

## The dhikr model (decided 2026-10-27)

A dhikr is one foundational entity: a single text that wirds, practices and goals build on. It holds no sequences, occasions or recommended counts; those belong to the features that use dhikrs. The shape is `$defs/dhikr` in [`contracts/dhikr-catalog/v1/dhikr-catalog.schema.json`](../../contracts/dhikr-catalog/v1/dhikr-catalog.schema.json). Custom dhikrs (3b) reuse it.

| Field | Meaning |
|---|---|
| `id`, `key` | Immutable UUIDv4 and catalog key (ADR-2026-07-13); goals and wirds reference `id` |
| `kind` | `quran`, `dhikr`, `dua`, `salawat`, `name_of_allah`; drives rendering |
| `arabic` | The recited text, with harakat |
| `title` | en, ar, ml |
| `transliteration` | One per language, in that language's script (en Latin, ml Malayalam); none for ar |
| `translation` | One per language; en required |
| `aliases` | Optional search terms per language (spelling variants, common names) |
| `audio` | None, or one recording: file, reciter, style, repetitions, duration, size, type, checksum, attribution |
| `references` | `quran`, `hadith`, `book`, `shaykh`, `other`; a `quran` dhikr needs a quran reference |
| `virtues` | Localized text, each citing at least one reference |

**Display language.** The app's language picks the title, transliteration and translation. If a field is missing in that language, the English value is shown. Arabic shows no transliteration.

## Scope

| In scope | Out of scope (and where it goes instead) |
|---|---|
| The shared catalog (`contracts/dhikr-catalog/v1/`): 113 dhikrs, 5 collections, references and virtues | Morning, evening and after-prayer adhkar: content the user supplies later, as a catalog change |
| Build-time generation of the catalog into each app, with a drift check | Catalog updates from the server without an app release (later; `contentRevision` is ready for it) |
| Search matching rule as shared fixtures | Custom dhikrs, tags and imported audio: slice 3b |
| Library: collections (collection tile), a collection's dhikrs, all dhikrs, search | Favourites, notes, user collections: later, in the personal layer |
| Dhikr detail, rendered by kind: Arabic, transliteration, translation, virtues with references, audio | Counting a dhikr: slice 4. Goals: slice 3 |
| Built-in audio: stream, or download and cache, then play and pause | Audio-synced highlighting, word-by-word: later |
| Server: the catalog registry (keys, ids, kinds) generated from the contract, ready for goal validation | A catalog API: not needed while every app bundles the catalog |

Platforms: server ☑ (registry only) · Android ☑ · iOS ☑ · web ☑

## Open questions

1. Review of the catalog's content items in [`SOURCES.md`](../../contracts/dhikr-catalog/v1/SOURCES.md): the user, then a scholar or native speaker, before release (not blocking the build).

## Behaviour inventory (step 2)

| Behaviour | Today (frozen apps) | Decision | Evidence |
|---|---|---|---|
| Built-in content | Hand-copied into each app; the server copy is truncated and has no titles; Android's translations repeat titles; only iOS has ar/ml | change: one catalog in `contracts/`, generated into each app | `awrad-android/.../BuiltInDhikrs.kt`, `awrad-ios/.../AwradSeedData.swift`, `awrad_server/.../built_in_registry.ex` |
| Identity | Catalog key paired with a fixed UUID; goals reference the UUID | keep | ADR-2026-07-13, `contracts/progress-model/v1/builtin-dhikrs.json` |
| Categories (11) | Primary plus extra categories; collections are code over categories, and they differ by platform | drop categories; collections are data: ordered lists, a dhikr can be in several | `LibraryFeaturedCollection.kt`, `LibraryFeatureModel.swift` |
| Collection tiles | Title, "N Dhikrs" and an arrow; hidden when empty | keep; the count comes from the catalog | `FeaturedCollections.kt:125` |
| Benefits | Android registry with a source; iOS guidance localized; some unsourced | change: virtues must cite a reference; unsourced ones wait for sources | `DhikrBenefits.kt`, `DhikrGuidance.swift` |
| Search | Title, transliteration, translation and Arabic, with differences by platform | change: one rule as fixtures (below), including aliases | `LibraryFilterPolicy.kt`, `LibraryFeatureModel.swift:239` |
| Audio | Remote MP3 per built-in, downloaded on demand; counts per play | keep; `repetitions` replaces counts per play | `DhikrEntity.kt`, `dhikrs.awrad.app` |
| Arabic display | Noto Naskh, centred; Qur'an through a reader preview | keep the `quran` text style; render by kind (below) | `DhikrDetailScreen.kt:280` |

## Domain and fixtures (step 3)

- **`CONTEXT.md`** gets these terms:
  - **Dhikr**, **Kind**, **Collection**, **Reference**, **Virtue**: as defined above.
  - **Catalog**: the built-in dhikrs and collections shipped with the apps.
- **Fixtures:** `contracts/dhikr-catalog/v1/fixtures/search.json`. Each case gives a query, the app language and the keys expected in order. The matching rule is:
  - case-fold;
  - strip Arabic harakat and tatweel;
  - unify alef forms (أ إ آ ٱ → ا) and ta marbuta/ha;
  - trim and collapse spaces;
  - substring match over title, transliteration, translation and aliases in the app language and in English, plus the Arabic text.
  - **Ordering:** title-prefix matches first, then catalog order.

## Rendering by kind

| Kind | Detail screen |
|---|---|
| `quran` | Arabic in the `quran` style, one ayah per line, with its reference label ("Qur'an 112:1–4") |
| `name_of_allah` | The name large and centred, then its meaning |
| `dhikr`, `dua`, `salawat` | Arabic in the `quran` style, then transliteration and translation |

On every kind, virtues are listed with their references below the text. Audio controls appear when the dhikr has audio.

## Platform work (step 5)

| Project | Work | Validation | Status |
|---|---|---|---|
| awrad-server-next | Generate the catalog registry module (key, id, kind) from the contract, with a drift test | `mix validate` | ☐ |
| awrad-android-next | Catalog generation; search fixtures runner; Library, collection, all-dhikrs, search and detail screens; audio playback | Gradle validation | ☐ |
| awrad-ios-next | Same as Android | `scripts/validate` | ☐ |
| awrad-web-next | Same, bundled; audio through the browser | `npm run validate` | ☐ |

## Integration evidence (step 6)

| Flow | Android | iOS | Web | Notes |
|---|---|---|---|---|
| Browse collections, open one, open a dhikr (en) | ☐ | ☐ | ☐ | |
| Same in ar (RTL) and ml | ☐ | ☐ | ☐ | Fallback to en where missing |
| Search by alias ("Astaghfirullah", "أستغفر الله") | ☐ | ☐ | ☐ | |
| Play and pause audio | ☐ | ☐ | ☐ | |

## Definition of done

Copy the checklist from the playbook and tick it here before closing.
