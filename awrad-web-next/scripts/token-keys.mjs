// The keys the web's token generators understand, per file and per entry. A key the
// generators don't know fails the build, so a token added to contracts/design-tokens/v1
// can't be silently left out of the web (generate-colors.mjs, generate-tokens.mjs).

/** Keys that describe a token and generate nothing. */
const NOTES = ["use"];

/** Top-level keys and the keys of each entry in a section, by file. */
export const KNOWN_KEYS = {
  colors: {
    top: ["version", "description", "palette", "roles", "contrast", "states"],
    entries: { roles: ["light", "dark", ...NOTES], states: ["opacity", ...NOTES] },
  },
  shape: {
    top: ["version", "description", "corners", "scale", "roles", "strokes", "elevation"],
    entries: {
      roles: ["radius", ...NOTES],
      strokes: ["width", "offset", ...NOTES],
      elevation: ["y", "blur", "color", ...NOTES],
    },
  },
  spacing: {
    top: ["version", "description", "scale", "roles", "sizes"],
    entries: { roles: ["space", ...NOTES], sizes: ["value", ...NOTES] },
  },
  typography: {
    top: ["version", "description", "fontFamily", "styles"],
    // iosTextStyle is for iOS's Dynamic Type; the web scales text with rem instead.
    entries: { styles: ["size", "lineHeight", "weight", "tabularNumbers", "fontFamily", "iosTextStyle", ...NOTES] },
  },
  motion: {
    // spring and haptic are mobile-only; the web's motions name only durations and easings.
    top: ["version", "description", "easing", "duration", "spring", "haptic", "motions", "reducedMotion"],
    entries: {},
  },
};

/** Throws when `file`'s parsed JSON has a top-level or entry key the generators don't know. */
export function checkKeys(file, json) {
  const known = KNOWN_KEYS[file];
  if (known === undefined) throw new Error(`token-keys.mjs: no known keys for ${file}.json`);
  for (const key of Object.keys(json)) {
    if (!known.top.includes(key)) {
      throw new Error(`${file}.json: unknown key "${key}"; teach the web's token generators about it first`);
    }
  }
  for (const [section, keys] of Object.entries(known.entries)) {
    for (const [name, entry] of Object.entries(json[section] ?? {})) {
      for (const key of Object.keys(entry)) {
        if (!keys.includes(key)) {
          throw new Error(
            `${file}.json ${section}.${name}: unknown key "${key}"; teach the web's token generators about it first`,
          );
        }
      }
    }
  }
}
