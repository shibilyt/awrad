# Goal presets v1

Built-in shortcuts for creating goals: seasons and occasions (slice 1b, [`docs/slices/01b-domain-hijri.md`](../../../docs/slices/01b-domain-hijri.md)).

- **What a preset is:** it fills in a goal's schedule, and sometimes its requirement. A goal made from one stores the full schedule; the key is only a label, and the rules never read it. So a device that doesn't know a newer preset still evaluates the goal correctly.
- **Editing:** if the user edits the dates, the goal is simply custom.
- **Custom occasions:** users build them with the same schedule kinds (`yearly`, `hijri_month_days`). They need no preset.
- **Adding a preset** is a content change: no rule or fixture changes.
- **Names** live in each platform's localization resources as `goal_preset_<key>`, in en, ar and ml. They're added when a screen first shows presets (slice 3).
- **The sentence's occasions** (slice 4, decision 6 and question 10) are every preset below: Ramadan (whole, first, middle and last ten, odd nights), six days of Shawwal, the first ten of Dhul Hijjah, Arafah, Ashura, the White Days and the sacred months. An occasion goal's streak counts occasions ("🔥 2 Ramadans"), except White Days, which count days, and six days of Shawwal, which counts months ([`../../goal-model/v1/README.md`](../../goal-model/v1/README.md), Streaks).

| Key | Schedule | Requirement |
|---|---|---|
| `ramadan` | Hijri 9/1–9/30 | user's choice |
| `ramadan_first_ten` | Hijri 9/1–9/10 | user's choice |
| `ramadan_middle_ten` | Hijri 9/11–9/20 | user's choice |
| `ramadan_last_ten` | Hijri 9/21–9/30 | user's choice |
| `ramadan_odd_nights` | Hijri 9/21, 9/23, 9/25, 9/27, 9/29 | user's choice |
| `dhul_hijjah_first_ten` | Hijri 12/1–12/10 | user's choice |
| `day_of_arafah` | Hijri 12/9 | user's choice |
| `ashura` | Hijri 1/9–1/10 | user's choice |
| `white_days` | 13–15 of every Hijri month | user's choice |
| `sacred_months` | Hijri 1/1–1/30, 7/1–7/30, 11/1–12/30 | user's choice |
| `shawwal_six_days` | Hijri 10/2–10/30 | 6 days per Hijri month |

`npm test` in `contracts/` validates the file against `goal-presets.schema.json`.
