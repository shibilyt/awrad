# Sources and review log: dhikr catalog v1

How `catalog.json` was put together from the frozen apps, every disagreement found between their copies, and what still needs a human or a scholar. The frozen projects are evidence only; nothing in them was changed.

## Sources

| Tag | File |
|---|---|
| **A** | `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/BuiltInDhikrs.kt` |
| **AB** | `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/DhikrBenefits.kt` (`DhikrBenefitsRegistry`) |
| **I** | `awrad-ios/awrad/awrad/Core/AwradSeedData.swift` |
| **ID** | `awrad-ios/awrad/awrad/Core/DhikrDisplayContent.swift` (ar/ml titles and "translations") |
| **IG** | `awrad-ios/awrad/awrad/Core/DhikrGuidance.swift` (benefits with ar/ml) |
| **S** | `awrad_server/lib/awrad_server/dhikr/built_in_registry.ex` |
| **P** | `contracts/progress-model/v1/asma-ul-husna.json` (the same as `awrad_server/priv/asma-ul-husna.json` on every shared field) |
| **PI** | `awrad_server/priv/asma-ul-husna.json`, `invocation_*` fields (made by `scripts/generate_asma_ul_husna.py`) |
| **L** | collection titles: Android `res/values{,-ar,-ml}/strings.xml`, iOS `{en,ar,ml}.lproj/Localizable.strings` |

The comparison was done mechanically, field by field. Every virtue text is verbatim from IG.

## Rules applied to all 13 hand-written dhikrs

- **Identity:** each key/id pair comes from `progress-model/v1/builtin-dhikrs.json`; A, I and S agree with it.
- **title.en** comes from A and I, which match for all 13. **title.ar** and **title.ml** come from ID.
- **arabic:** A and I are byte-identical except for Surah Ikhlas and Swalath al Nariyya (see their rows). S holds only a short prefix for 7 of the 13 dhikrs, so it was never used.
- **transliteration.en** comes from A and I, which match for all 13, except where they only repeat the title (Fatih, Nariyya). No frozen source has a Malayalam-script transliteration, so `transliteration.ml` is absent everywhere.
- **translation.en:** A's `translation` repeats the title for 12 of the 13, so I is used, except where noted. **translation.ar/ml** come from ID, except where ID repeats the title. Several ar "translations" just restate the Arabic without harakat; they were kept so Arabic users don't fall back to English.
- **audio:**
  - `file` is the remote file name from A's `audioUrl`, which equals I's `audioURL`. A and I also have a local cache name (`audioFileName`, for example `tahleel.mp3`); it's a platform detail and was dropped.
  - `repetitions` is the old `audioCountPerPlay`: 2 for tahleel and ya-wahhabu, 1 for the rest. A and I agree.
  - `byteSize` and `mimeType` come from the HEAD check below.
  - `style` is set to `recitation` for all 13, but **nobody has listened to confirm it**; some may be `melodic`.
  - `reciter`, `durationMs` and `sha256` are unknown; getting them would mean downloading the files.
- **Virtues:**
  - A benefit becomes a virtue only if it cites a source. Its en/ar/ml text is IG's wording. IG is a revision of AB with softer wording, and its ar/ml translate that wording.
  - Benefit *titles* were dropped, because a virtue is text only. They're still in IG and AB.
  - Hadith sources became `hadith` references (`collection` is `Jami at-Tirmidhi`, `Sunan Abi Dawud` or `Sahih Muslim`; `number` is the cited number). `Quran x:y[-z]` became `quran` references. `grade` and `narrator` are left empty.
  - **The numbering scheme is unverified:** the numbers match the sunnah.com numbering as far as checked.
- **Unsourced benefits** were left out of `virtues` and are listed below, waiting for a reference.
- **Suggested goals** (AB, IG) were dropped; they belong to practices and goals.
- I's seed `benefits` strings for tahleel and isthighfar were never shown, because IG overrides them, so they were dropped.

## Kind

| Kind | Dhikrs |
|---|---|
| `quran` | `surah-ikhlas` (reference 112:1–4) |
| `dhikr` | `tahleel`, `isthighfar`, `ya-wahhabu` |
| `salawat` | the 6 swalaths |
| `dua` | `ramadan-dhikr`, `ramadan-first-ten-nights`, `ramadan-second-ten-nights` |
| `name_of_allah` | the 100 Asma-ul Husna names |

Two kinds are judgement calls:

- **ya-wahhabu** invokes a name of Allah, but it's `dhikr` here. It was a praise dhikr with audio, and `name_of_allah` is reserved for the Asma collection.
- **ramadan-dhikr** combines the shahada, istighfar and a supplication. It's `dua` because it ends asking for Paradise; `dhikr` would also be defensible.

## Per dhikr

| Key | Where each field came from | Disagreements found | Needs review |
|---|---|---|---|
| `surah-ikhlas` | arabic: I (= A without ayah numbers). translit: A=I. translation.en: **authored**; ar/ml: none. reference: Qur'an 112:1–4 (A=I). virtues: none. | A writes ayah numbers `(1)`–`(4)` and I doesn't; the numbers were **dropped** (one ayah per line). S has only ayah 1, with `ْ` instead of `ۡ`. A, I and ID all give the title as the "translation", in every language. | The authored English translation. The transliteration covers only ayah 1. The Arabic opens with the basmala, but the reference is 112:1–4: keep it or not? The orthography is Uthmani (`ۡ`, `ٱللَّهِ`), unlike the rest of the catalog. A well-sourced virtue, "equal to a third of the Qur'an" (Bukhari 5013), is missing from every source. |
| `tahleel` | All from A=I; translation I; virtues IG (3; en identical in AB). | None in the text. IG's ar/ml say "among the heaviest" where en says "nothing heavier". | **Tirmidhi 3462** for "heaviest on the scales" looks wrong: the bitaqah hadith is Tirmidhi 2639. Tirmidhi 3585 is the Arafah hadith, which gives the longer formula (…wahdahu la sharika lah…); the en quote shortens it. |
| `ya-wahhabu` | A=I; translation I ("O Bestower."). virtues: none (both benefits are unsourced). | AB says the dhikr "opens doors of provision and removes financial difficulties"; IG softens this. | The unsourced benefits. The same recited text, `يَا وَهَّابُ`, is also `asma-ul-husna-al-wahhab` (transliterated "Ya Wahhab"): two identities, one text. |
| `isthighfar` | A=I; translation I; virtues IG (Abu Dawud 1518, Qur'an 71:10, 71:10–12). | AB quotes the hadith and the ayah directly; IG paraphrases them. IG's wording was kept. | **Abu Dawud 1518** is graded weak by many scholars; add a `grade` or soften the virtue. The key keeps the spelling "isthighfar" (it's immutable). |
| `swalath-al-fathimiyya` | A=I; translation I; virtues: none. | AB says it is "attributed to Sayyida Fatima Az-Zahra"; IG dropped that claim, and it was kept out. | The attribution, which could become a `shaykh` or `book` reference. The audio file is exactly the same size as isthighfar's (103,444 bytes) but has a different ETag. Listen to it to confirm it's the right recording. |
| `swalath` | A=I; translation I; virtues IG (Muslim 408, Tirmidhi 484). | S has only the first half (`صَلَّى ٱللَّٰهُ عَلَىٰ مُحَمَّدٍ`). | The transliteration ends "wa **sallim**", but the Arabic `وَسَلَّمَ` reads "wa **sallam**". One of them is wrong; check against the audio. |
| `swalath-sayyidina` | A=I; translation I; virtues IG (Abu Dawud 1047, Friday). | S stops after `مُحَمَّدٍ`. | The en/ml title is "Swalath 2" / "സ്വലാത്ത് 2", which describes nothing (ar is `الصلاة على سيدنا محمد`). Rename it. The Friday virtue is about salawat in general, not this wording. |
| `swalath-al-fatih` | arabic: A=I without the `❁` separators. translit: **authored**. translation.en: **authored**; ar/ml from ID (partial). virtues: none. | S stops after `أُغْلِقَ` (the known truncation). A and I give the title as the transliteration. I's translation covers only the first phrase. AB's claim that "a single recitation equals 600,000 swalaths" has no source, and IG had already removed it. | The authored transliteration and English translation. The ar/ml translations are partial. Attribution: traditionally Shaykh Muhammad al-Bakri (a `shaykh` reference). Confirm that the 600,000 claim stays out. |
| `swalath-al-nariyya` | arabic: **A** (the complete copy). translit: **authored**. translation.en: **authored**; ar/ml from ID (partial). virtues: none. | I stops after `وَحُسْنُ الْخَوَاتِمِ`, missing `وَيُسْتَسْقَى الْغَمَامُ … مَعْلُومٍ لَكَ`. S drops `وَسَلِّمْ سَلَامًا تَامًّا` and stops after `مُحَمَّدٍ`. A and I give the title as the transliteration. | Most sources spell it `الْخَوَاتِيمِ`; this copy has `الْخَوَاتِمِ`. The authored transliteration and translation. The ar/ml translations are partial. It is also called *Salat Tafrijiyya*. |
| `swalath-for-debt` | arabic and translit: A=I. translation.en: **A** (complete); ar/ml: ID (partial). virtues: none in any source. | I's translation drops "the Muslim men … the Muslim women". ID's ar/ml mention only the believers. S stops after `وَرَسُولِكَ`. | `وَلِلْمُؤْمِنَاتِ` (with *li-*) after `وَعَلَى` reads oddly. The commonly narrated wording is `…وَصَلِّ عَلَى الْمُؤْمِنِينَ وَالْمُؤْمِنَاتِ وَالْمُسْلِمِينَ وَالْمُسْلِمَاتِ`; verify the text against its source. Nothing sources the "for debt" link; the audio name points to Tajul Ulama. The transliteration alone uses scholarly diacritics (ā, ṣ, ʿ) and ends with a period. |
| `ramadan-dhikr` | A=I; translation I; virtues: none. | S has only the first phrase. | No source is cited. |
| `ramadan-first-ten-nights` | A=I; translation I; virtues: none. | The title says "Nights"; the benefits say "days". | The "first ten = mercy" framing is usually traced to a narration from Salman al-Farisi (Ibn Khuzaymah) that is widely graded weak; no source is cited. Settle on nights or days. |
| `ramadan-second-ten-nights` | A=I; translation I; virtues: none. | Same nights/days mismatch. | Same as the first ten nights. |

## Benefits waiting for a reference

None of these cite a source, so they aren't in `virtues`. IG holds the en/ar/ml text; AB holds the en-only items.

| Dhikr | Benefit (IG title; AB-only items marked) |
|---|---|
| `surah-ikhlas` | Protection and remembrance (I seed string; ar/ml in IG) |
| `ya-wahhabu` | The Bestower of gifts; Provision and sustenance |
| `swalath-al-fathimiyya` | Swalath upon the Light; Spiritual illumination |
| `swalath-sayyidina` | Complete swalath |
| `swalath-al-fatih` | The Opening Prayer; Guidance to the straight path; *AB only:* Immense reward (600,000) |
| `swalath-al-nariyya` | Relief from difficulties; Fulfillment of needs; *AB only:* Rain and blessings |
| `ramadan-dhikr` | Comprehensive Ramadan dhikr; Gates of Paradise |
| `ramadan-first-ten-nights` | Seeking divine mercy; *AB only:* Most Merciful of the merciful |
| `ramadan-second-ten-nights` | Seeking forgiveness in Ramadan; *AB only:* Lord of all worlds |

## Asma-ul Husna (100 names)

- **Identity, order and translation** come from P; translation is P's `meaning`, in en only. The server copy matches P on every shared field.
- **arabic and transliteration.en** use the invocation form from PI, which the native apps display (`Ya Rahman`, `يَا رَحْمَٰنُ`). `kind` is `name_of_allah`. There's no audio, no references and no virtues.
- **Title:** en and ml use the invocation transliteration; ar uses the plain Arabic name from P. The apps used the invocation transliteration for every language.
- **The plain transliteration** (`Ar-Rahman`) and the bare name (`Rahman`) are carried only as `aliases.en`, because the settled dhikr shape has no name field.
- **Two corrections to the generated invocations:**
  - `asma-ul-husna-malik-ul-mulk`: `يَا مَالِكُ ٱلْمُلْكِ` became `يَا مَالِكَ ٱلْمُلْكِ`. A vocative in an iḍāfa takes the accusative, as in Qur'an 3:26. The transliteration is now `Ya Malikal-Mulk`.
  - `asma-ul-husna-dhul-jalali-wal-ikram`: the transliteration is now `Ya Dhal-Jalali wal-Ikram`, to match the existing accusative `يَا ذَا`.
- **Review:**
  - ml (and ar) translations for all 100 names.
  - A scholar's pass over the generated invocation forms: they're made by stripping `ال` and the first-letter shadda.
  - The provenance of the meanings (P cites https://99namesofallah.name/).
  - The overlap between `asma-ul-husna-al-wahhab` and `ya-wahhabu`.

## Collections

| Key | Members | Titles (en / ar / ml) and source |
|---|---|---|
| `daily-essentials` | tahleel, ya-wahhabu, isthighfar, surah-ikhlas | Daily Essentials / أساسيات يومية / ദൈനംദിന അടിസ്ഥാനങ്ങൾ (iOS; Android has en only) |
| `dhikrs` | tahleel, ya-wahhabu, isthighfar | Dhikrs / الأذكار / ദിക്‌റുകൾ (iOS; Android has en only) |
| `swalaths` | the 6 salawat, in seed order | Swalaths / الصلاة على النبي ﷺ / സ്വലാത്തുകൾ |
| `ramadan` | the 3 Ramadan dhikrs, in seed order | Ramadan / رمضان / റമദാൻ (Android and iOS agree) |
| `asma-ul-husna` | 100 names, numbers 1–100 | Asma-ul Husna / الأسماء الحسنى / അസ്മാഉൽ ഹുസ്ന (Android and iOS agree) |

- **Membership** follows Android's `LibraryFeaturedCollection` and iOS's `LibraryFeaturedCollection.dhikrs(in:)`, which agree. With no morning dhikrs, Daily Essentials is praise + forgiveness + quran, and Dhikrs is praise + forgiveness + general; no built-in dhikr is general.
- **Order:** the frozen apps sorted by category name (forgiveness, praise, quran), so isthighfar came first. Collections now carry an explicit order, and the slice brief's order was used.
- **Swalaths titles:** for ar, the iOS tile says `الصلوات`, but both apps' category string says `الصلاة على النبي ﷺ`. The category string was chosen because `الصلوات` can also mean the ritual prayers. For ml, the iOS tile's plural `സ്വലാത്തുകൾ` was chosen to match en "Swalaths"; the category string is `സ്വലാത്ത്`.

## Audio (HEAD check, 2026-10-27)

All 13 files at `https://dhikrs.awrad.app/` returned `200 audio/mpeg`:

| File | Bytes |
|---|---|
| `ikhlas.mp3` | 139,851 |
| `1736077531573-g8kajuv6fww-tahleel.mp3` | 171,362 |
| `ya-wahhabu-2.mp3` | 29,100 |
| `1736083253280-c2kcxrk9cj-isthighfar.mp3` | 103,444 |
| `1736075795464-yh0twy42m-swalath-fatimiya.mp3` | 103,444 |
| `1736510596621-oqiqm8yj15l-swalath-regular.mp3` | 165,093 |
| `1737527316685-7gkeld0j3oy-swalath-1.mp3` | 195,395 |
| `swalath_fatih.mp3` | 241,812 |
| `swalath_nariyya.mp3` | 463,782 |
| `swalath_tajul_ulama.mp3` | 131,603 |
| `ramadan_full.mp3` | 131,679 |
| `ramadan_first10.mp3` | 66,743 |
| `ramadan_second10.mp3` | 74,210 |

The isthighfar and swalath-fatimiya files are the same size but have different ETags. The Asma-ul Husna names have no audio.

## Aliases

- **From the frozen apps.** Titles and notification names (`notif_goal_name_*`) match the titles everywhere, so they add nothing. The aliases that do come from the frozen apps:
  - "Istighfar", the spelling used across the Android/iOS strings;
  - "Fatimiya", from the audio file name;
  - "Tajul Ulama", from the audio file name;
  - `الوهاب` and `അൽ വഹ്ഹാബ്`, from the IG benefit titles;
  - `ലാ ഇലാഹ ഇല്ലല്ലാഹ്`, from IG;
  - `അസ്തഗ്ഫിറുല്ലാഹ്`, from Android's `community_feed_daily_dhikr_transliteration`.
- **Common variants added in this slice (review them):**
  - Tahlil, Lailahaillallah;
  - Al-Ikhlas, Qul Huwallahu Ahad, Surah 112;
  - Astaghfirullah, Astaghfirullahal Azim;
  - Salawat, Salat or Salatul for the swalaths, Durood;
  - Salat Tafrijiyya and `الصلاة التفريجية` for Nariyya;
  - Ramzan;
  - First/Second Ashra;
  - the opening words of the Ramadan duas.
- **Asma-ul Husna:** the plain transliteration and the bare name (`Ar-Rahman`, `Rahman`).
- **Shared aliases:** "Ya Wahhab" and "Wahhab" belong to ya-wahhabu, and the Asma entry al-wahhab has "Al-Wahhab" and "Wahhab". Search returns both, which is intended.
- **Malayalam-script transliterations** (`transliteration.ml`): no frozen source has them, so none were added.

## Not modelled yet

- **Removal status** (`active` / `retired`): it exists in `builtin-dhikrs.json` but not here yet.
- **Script style:** Uthmani for Qur'an and standard for the rest, which fonts depend on.
