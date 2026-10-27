// The tokens the key components need (contracts/design-system/v1/components.md): elevation,
// component sizes and shapes, largeTitle, the select motion, the forced colour scheme, and the
// generators failing on keys they don't know, and the safe-area insets (viewport-fit=cover).
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, expect, test } from "vitest";
import { classProblem, rawValues, vocabulary } from "./check-raw-values.mjs";
import { SOURCE as COLORS, kebab, renderColorsCss } from "./generate-colors.mjs";
import { TARGET, readTokens, renderTokensCss } from "./generate-tokens.mjs";

const tokens = readTokens();
const colors = JSON.parse(readFileSync(COLORS, "utf8"));
const css = renderTokensCss(tokens);
const colorsCss = renderColorsCss(colors);
const vocab = vocabulary();

function withChange(file, change) {
  const copy = structuredClone(tokens);
  change(copy[file]);
  return copy;
}

describe("elevation", () => {
  test("floating is a custom property in the shadow role and the shadow-floating utility", () => {
    expect(tokens.shape.elevation.floating).toMatchObject({ y: 4, blur: 16, color: "shadow" });
    expect(css).toContain("--awrad-elevation-floating: 0 4px 16px var(--awrad-color-shadow);");
    expect(css).toContain("@utility shadow-floating {\n  box-shadow: var(--awrad-elevation-floating);\n}");
  });

  test("Tailwind's own shadows are removed", () => {
    for (const scale of ["shadow", "inset-shadow", "drop-shadow", "text-shadow"]) {
      expect(css).toContain(`--${scale}-*: initial;`);
    }
  });

  test("the shadow colour is transparent in dark", () => {
    const dark = colorsCss.split("@media (prefers-color-scheme: dark)")[1] ?? "";
    expect(colors.roles.shadow.dark).toBe("#00000000");
    expect(dark).toContain("--awrad-color-shadow: #00000000;");
  });

  test("rejects an elevation in a colour that isn't a role", () => {
    expect(() => renderTokensCss(withChange("shape", (shape) => (shape.elevation.floating.color = "ink")))).toThrow(
      /elevation\.floating\.color/,
    );
  });
});

describe("component tokens", () => {
  test("every component size is a spacing size", () => {
    for (const size of ["topBar", "navBar", "navPillWidth", "roundButtonSmall", "avatar", "switchThumb", "stepDot"]) {
      expect(css).toContain(`--spacing-${kebab(size)}: var(--awrad-size-${kebab(size)});`);
    }
    expect(css).toContain("--awrad-size-tab-indicator-height: 4px;");
  });

  test("the component shapes are radius roles; the fully rounded tab indicator has no squircle", () => {
    expect(css).toContain("--awrad-radius-step-dot: var(--awrad-radius-xxxs);");
    expect(css).toContain("--awrad-radius-content-sheet: var(--awrad-radius-3xl);");
    expect(css).toContain("--awrad-radius-tab-indicator: var(--awrad-radius-full);");
    expect(css).not.toContain("--corner-shape-tab-indicator");
  });

  test("largeTitle is a text style", () => {
    expect(css).toContain("--awrad-text-large-title-size: 2.125rem;");
    expect(css).toContain("--text-large-title: var(--awrad-text-large-title-size);");
  });

  test("select is a web motion; segmentIndicator (a slide) isn't", () => {
    expect(css).toContain("--awrad-motion-select-color-duration: var(--awrad-duration-color);");
    expect(css).toContain("--awrad-motion-select-easing: var(--awrad-ease-linear);");
    expect(css).not.toContain("segment-indicator");
  });
});

describe("forced colour scheme", () => {
  test("data-color-scheme sets every role for one scheme, after the system's", () => {
    const roles = Object.entries(colors.roles);
    for (const scheme of ["light", "dark"]) {
      const block = colorsCss.split(`[data-color-scheme="${scheme}"] {`)[1]?.split("}")[0] ?? "";
      expect(block).toContain(`color-scheme: ${scheme};`);
      for (const [role, value] of roles) expect(block).toContain(`--awrad-color-${kebab(role)}: ${value[scheme]};`);
    }
    expect(colorsCss.indexOf("[data-color-scheme")).toBeGreaterThan(colorsCss.indexOf("prefers-color-scheme: dark"));
  });
});

describe("unknown keys", () => {
  test.each([
    ["a new top-level shape section", "shape", (shape) => (shape.blur = {}), /shape\.json: unknown key "blur"/],
    ["a new key on a size", "spacing", (spacing) => (spacing.sizes.icon.dark = 1), /sizes\.icon: unknown key "dark"/],
    ["a new key on a style", "typography", (type) => (type.styles.body.italic = true), /styles\.body/],
    ["a new motion section", "motion", (motion) => (motion.webSlide = {}), /unknown key "webSlide"/],
  ])("tokens: rejects %s", (_, file, change, message) => {
    expect(() => renderTokensCss(withChange(file, change))).toThrow(message);
  });

  test("colours: rejects a new top-level section and a new key on a role", () => {
    expect(() => renderColorsCss({ ...colors, gradients: {} })).toThrow(/colors\.json: unknown key "gradients"/);
    const role = structuredClone(colors);
    role.roles.primary.highContrast = "#000000";
    expect(() => renderColorsCss(role)).toThrow(/roles\.primary: unknown key "highContrast"/);
  });
});

describe("check-raw-values: shadows", () => {
  test.each([
    "shadow",
    "shadow-lg",
    "shadow-md",
    "shadow-shadow",
    "drop-shadow-md",
    "inset-shadow-sm",
    "text-shadow-sm",
  ])("flags %s", (candidate) => {
    expect(classProblem(candidate, vocab)).toBe("shadow that isn't an elevation token (shadow-floating)");
  });

  test("allows the elevation, and flags raw shadows in hand-written CSS", () => {
    expect(classProblem("shadow-floating", vocab)).toBeNull();
    expect(classProblem("md:shadow-floating", vocab)).toBeNull();
    expect(classProblem("shadow-[0_4px_16px_black]", vocab)).toBe("arbitrary value");
    expect(rawValues("  box-shadow: 0 4px 16px var(--awrad-color-shadow);", "css")).toHaveLength(1);
    expect(rawValues("  box-shadow: var(--awrad-elevation-floating);", "css")).toEqual([]);
  });
});

describe("safe areas", () => {
  const ui = dirname(TARGET);
  const html = readFileSync(join(ui, "../../../index.html"), "utf8");
  const theme = readFileSync(join(ui, "theme.css"), "utf8");

  test("the viewport covers the whole screen, so env(safe-area-inset-*) is set on iOS", () => {
    expect(html).toMatch(/<meta name="viewport" content="[^"]*viewport-fit=cover[^"]*"/);
  });

  test("the safe-area utilities pad by each inset, and the bottom bar sits inside them", () => {
    expect(theme).toContain("@utility safe-area-x {");
    expect(theme).toContain("padding-left: env(safe-area-inset-left, var(--awrad-space-none));");
    expect(theme).toContain("padding-top: env(safe-area-inset-top, var(--awrad-space-none));");
    expect(theme).toContain("padding-bottom: env(safe-area-inset-bottom, var(--awrad-space-none));");
    expect(theme).toContain(
      "left: calc(var(--awrad-space-page-margin) + env(safe-area-inset-left, var(--awrad-space-none)));",
    );
    expect(theme).toContain(
      "bottom: calc(var(--awrad-space-lg) + env(safe-area-inset-bottom, var(--awrad-space-none)));",
    );
  });
});
