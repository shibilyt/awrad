# Fonts

The font files every app bundles (design system, decided 2026-10-27). Each app's validation checks that its copies are byte-identical to these, using `SHA256SUMS`.

| Family | Files | Used for |
|---|---|---|
| **Google Sans Flex Rounded** | `googlesansflexrounded_{regular,medium,semibold,bold}.ttf` | All interface text in Latin script: headings, body, labels, buttons. This is the font of the frozen Android and iOS apps: Google Sans Flex with its rounded axis at 100, as static instances |
| **Noto Naskh Arabic** | `notonaskharabic_{regular,medium,semibold,bold}.ttf` | Qur'anic and dhikr text in Arabic script |

Rules:
- **Interface text in Arabic or Malayalam** uses each platform's system font for that script, as the frozen apps did. Google Sans Flex has no Arabic or Malayalam glyphs.
- **Weights:** Regular 400, Medium 500, SemiBold 600, Bold 700. Don't use synthetic bold or italic.
- **Licence:** both families are under the SIL Open Font License 1.1 (stated in each font's metadata).
  - Google Sans Flex's licence text is `OFL-GoogleSansFlex.txt`, from `google/fonts` (`ofl/googlesansflex/OFL.txt`).
  - Noto Naskh Arabic's licence text isn't in the repo yet.

To change a font: replace the file here, run `shasum -a 256 *.ttf > SHA256SUMS`, and copy it into each app (each app's validation will say which copies are stale).
