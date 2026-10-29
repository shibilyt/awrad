# Places v1: the bundled city list

The cities users can pick as their location without GPS or a network (slice 3d, [brief](../../../docs/slices/03d-practice-settings.md)). Every app generates its copy from `cities.json` at build time, as with the dhikr catalog, so search gives the same results everywhere.

| File | What it is |
|---|---|
| `cities.json` | The list (`urn:awrad:places:1#/$defs/city_list`), one city per line |
| `places.schema.json` | `urn:awrad:places:1`: a city, the list, a city ID |
| `fixtures/city_search.json` | Query and limit → ranked city IDs (Android, iOS, web) |

## Source and licence

`cities.json` is built by `tools/build-cities.mjs` from GeoNames' `cities15000.txt` and `admin1CodesASCII.txt` (download.geonames.org/export/dump), under **CC BY 4.0**. Each app's About shows the `attribution` line. The dump itself isn't committed.

```bash
cd contracts && npm run build:cities -- /path/to/geonames-dump
```

Rebuilding from a newer dump can change `city_search` results; the checker then says which cases to update.

## Which cities

- **Population:** at least 15,000 people in Kerala (`IN.13`) and the six Gulf states (`SA`, `AE`, `KW`, `QA`, `BH`, `OM`), and at least 50,000 elsewhere. The thresholds are data in the builder and in the file's `thresholds`.
- **Skipped:** sections of cities (`PPLX`) and historical, abandoned or destroyed places.
- 11,976 cities, about 2.6 MB of JSON (680 KB gzipped). The web loads it only when search opens.

## A city

```json
{"id":1265873,"name":"Kozhikode","country":"IN","region":"Kerala","latitude":11.248,"longitude":75.7804,"population":550440,"aliases":["Calecute","Calicut","Kozhikkot","കോഴിക്കോട്"]}
```

(aliases shortened here.)

- `id` is the GeoNames ID; a device location chosen from the list keeps it as `city_id`.
- `name` is GeoNames' ASCII name ("Ponnani", not "Ponnāni"), shown in every language. Arabic and Malayalam display names would need GeoNames' 205 MB alternate-names file; that's a later option.
- `country` is ISO 3166-1 alpha-2; each app shows the country's name in the app language from its platform locale data.
- `region` is the first-level region's ASCII name, or `null`.
- `aliases` are names search matches but never shows: Arabic- and Malayalam-script names, capitalised Latin names of up to three words (older and English names such as Calicut and Trivandrum), and the name with its diacritics.

## Search

`fixtures/city_search.json`; the reference is `searchCities` in `tools/practice-settings-rules.mjs`.

1. **Search key** of the query and of every name:
   - NFKD;
   - Latin accents (U+0300–U+036F), Arabic harakat (U+064B–U+065F, U+0670) and tatweel removed;
   - Arabic alef forms (آ أ إ ٱ) to ا, alef maksura ى to ي, ta marbuta ة to ه;
   - apostrophes removed;
   - lowercased;
   - every run of characters that aren't letters, marks or digits to one space, then trimmed.

   Malayalam vowel signs are marks and stay.
2. **A query whose key is empty finds nothing.**
3. **Matching.** A name matches exactly, by its start, or by the start of a later word. A city's tier is its best match:

   | Tier | Match |
   |---|---|
   | 0 | The name, exactly |
   | 1 | An alias, exactly |
   | 2 | The name's start |
   | 3 | An alias's start |
   | 4 | A later word of the name |
   | 5 | A later word of an alias |

4. **Order:** tier, then population (larger first), then ID; at most `limit` results.

On phones, results from the platform's own place search (online only) are listed after these, under their own heading, and saved with `source` `search`.
