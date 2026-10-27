// The shape, spacing, type and motion pipeline: contracts/design-tokens/v1 → tokens.gen.css
// → Tailwind names, and the check that keeps raw values out of the app.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, expect, test } from "vitest";
import { classProblem, rawValues, vocabulary } from "./check-raw-values.mjs";
import { SOURCE as COLORS, kebab } from "./generate-colors.mjs";
import { FONT_KEYS, TARGET, readTokens, renderTokensCss, tokenNames } from "./generate-tokens.mjs";

const tokens = readTokens();
const css = renderTokensCss(tokens);
const [root = "", rest = ""] = css.split("@theme inline {");
const theme = rest.split("}")[0] ?? "";
const vocab = vocabulary();

/** The tokens with one file changed, for the generator's failure cases. */
function withChange(file, change) {
  const copy = structuredClone(tokens);
  change(copy[file]);
  return copy;
}

describe("tokens.gen.css: shape and spacing", () => {
  test("is the committed file", () => {
    expect(readFileSync(TARGET, "utf8")).toBe(css);
  });

  test("has every radius, in px, roles pointing at the scale, and continuous corners except fully rounded", () => {
    for (const [step, value] of Object.entries(tokens.shape.scale)) {
      expect(root).toContain(
        `--awrad-radius-${step}: ${value === "full" ? "calc(infinity * 1px)" : `${String(value)}px`};`,
      );
      expect(theme).toContain(`--radius-${step}: var(--awrad-radius-${step});`);
    }
    for (const [role, { radius }] of Object.entries(tokens.shape.roles)) {
      expect(root).toContain(`--awrad-radius-${kebab(role)}: var(--awrad-radius-${radius});`);
      expect(theme).toContain(`--radius-${kebab(role)}: var(--awrad-radius-${kebab(role)});`);
      const squircle = `--corner-shape-${kebab(role)}: squircle;`;
      if (radius === "full") expect(css).not.toContain(squircle);
      else expect(css).toContain(squircle);
    }
    expect(css).toContain("@utility rounded-* {");
    expect(css).toContain("@utility rounded-t-* {");
    expect(css).toContain("@supports (corner-shape: squircle)");
    expect(theme).toContain("--radius-*: initial;");
  });

  test("plain corners when shape.json doesn't ask for continuous ones", () => {
    const plain = renderTokensCss(withChange("shape", (shape) => (shape.corners = "circular")));
    expect(plain).not.toContain("corner-shape");
    expect(plain).toContain("--radius-card: var(--awrad-radius-card);");
  });

  test("has every space and size; none is Tailwind's 0, and the default numeric scale is gone", () => {
    for (const [step, value] of Object.entries(tokens.spacing.scale)) {
      expect(root).toContain(`--awrad-space-${step}: ${String(value)}px;`);
    }
    expect(theme).toContain("--spacing-*: initial;");
    expect(theme).toContain("--spacing-0: var(--awrad-space-none);");
    expect(theme).toContain("--spacing-card-padding: var(--awrad-space-card-padding);");
    expect(root).toContain("--awrad-space-card-padding: var(--awrad-space-lg);");
    expect(theme).toContain("--spacing-touch-target: var(--awrad-size-touch-target);");
    expect(root).toContain("--awrad-size-touch-target: 48px;");
    expect(theme).toContain("--spacing-control: var(--awrad-size-control);");
    expect(root).toContain("--awrad-size-control: 56px;");
    expect(theme).toContain("--spacing-logo: var(--awrad-size-logo);");
    expect(theme).not.toMatch(/--spacing:/);
  });

  test("content widths (<name>MaxWidth sizes) are the only Tailwind containers: max-w-content, max-w-dialog", () => {
    expect(root).toContain("--awrad-size-content-max-width: 448px;");
    expect(root).toContain("--awrad-size-dialog-max-width: 384px;");
    expect(theme).toContain("--container-*: initial;");
    expect(theme).toContain("--container-content: var(--awrad-size-content-max-width);");
    expect(theme).toContain("--container-dialog: var(--awrad-size-dialog-max-width);");
    expect(theme).not.toContain("--spacing-content-max-width");
    expect(theme.match(/--container-[\w-]+:/g)).toHaveLength(
      Object.keys(tokens.spacing.sizes).filter((size) => size.endsWith("MaxWidth")).length,
    );
  });

  test("has every stroke as a width (and offset), with border-*, outline-* and outline-offset-* classes", () => {
    for (const [stroke, { width, offset }] of Object.entries(tokens.shape.strokes)) {
      const name = kebab(stroke);
      expect(root).toContain(`--awrad-stroke-${name}: ${String(width)}px;`);
      expect(css).toContain(`@utility border-${name} {\n  border-width: var(--awrad-stroke-${name});\n}`);
      expect(css).toContain(
        `@utility outline-${name} {\n  outline-style: solid;\n  outline-width: var(--awrad-stroke-${name});\n}`,
      );
      if (offset === undefined) expect(css).not.toContain(`outline-offset-${name}`);
      else expect(root).toContain(`--awrad-stroke-${name}-offset: ${String(offset)}px;`);
    }
    expect(root).toContain("--awrad-stroke-field-error: 1.5px;");
    expect(css).toContain(
      "@utility outline-offset-focus-ring {\n  outline-offset: var(--awrad-stroke-focus-ring-offset);\n}",
    );
  });
});

describe("tokens.gen.css: type and motion", () => {
  test("has every text style in rem with line height and weight; counter has tabular digits", () => {
    for (const [style, value] of Object.entries(tokens.typography.styles)) {
      const name = kebab(style);
      expect(root).toContain(`--awrad-text-${name}-size: ${String(value.size / 16)}rem;`);
      expect(root).toContain(`--awrad-text-${name}-line-height: ${String(value.lineHeight / 16)}rem;`);
      expect(root).toContain(`--awrad-text-${name}-weight: ${String(value.weight)};`);
      expect(theme).toContain(`--text-${name}--line-height: var(--awrad-text-${name}-line-height);`);
      expect(theme).toContain(`--text-${name}--font-weight: var(--awrad-text-${name}-weight);`);
    }
    expect(root).toContain("--awrad-text-title-size: 1.375rem;");
    expect(css).toContain("@utility text-counter {\n  font-variant-numeric: tabular-nums;\n}");
    expect(theme).toContain("--font-weight-*: initial;");
    expect(theme).toContain("--font-weight-semibold: 600;");
    expect(theme).not.toContain("--font-weight-black");
    expect(root).toContain("--awrad-text-input-size: 1rem;");
  });

  test("a style with its own fontFamily uses that family's theme font; the others inherit", () => {
    expect(root).toContain("--awrad-text-quran-font-family: var(--font-arabic);");
    expect(css).toContain("@utility text-quran {\n  font-family: var(--awrad-text-quran-font-family);\n}");
    const ownFamily = Object.entries(tokens.typography.styles).filter(([, style]) => style.fontFamily !== undefined);
    expect(ownFamily.map(([style]) => style)).toEqual(["quran", "quranLine", "nameOfAllah"]);
    expect(css).toContain("@utility text-quran-line {\n  font-family: var(--awrad-text-quran-line-font-family);\n}");
    expect(css).toContain(
      "@utility text-name-of-allah {\n  font-family: var(--awrad-text-name-of-allah-font-family);\n}",
    );
    expect(root.match(/-font-family:/g)).toHaveLength(ownFamily.length);
    expect(FONT_KEYS[tokens.typography.fontFamily]).toBe("sans");
  });

  test("every font family the generator knows is the first family of theme.css's --font-<key>", () => {
    const themeCss = readFileSync(join(dirname(TARGET), "theme.css"), "utf8");
    for (const [family, key] of Object.entries(FONT_KEYS)) {
      expect(themeCss).toContain(`--font-${key}: "${family}",`);
    }
  });

  test("text style names never collide with colour roles (both are text-*)", () => {
    const roles = Object.keys(JSON.parse(readFileSync(COLORS, "utf8")).roles).map(kebab);
    expect(tokenNames(tokens).text.filter((name) => roles.includes(name))).toEqual([]);
  });

  test("has durations, easings and only the web's motions; Tailwind's eases and animations are removed", () => {
    expect(root).toContain("--awrad-ease-emphasized: cubic-bezier(0.2, 0, 0, 1);");
    expect(root).toContain("--awrad-duration-fade: 100ms;");
    expect(root).toContain("--awrad-motion-web-page-fade-in: var(--awrad-duration-color);");
    expect(root).toContain("--awrad-motion-web-page-fade-out: var(--awrad-duration-fade);");
    expect(root).toContain("--awrad-motion-web-page-easing: var(--awrad-ease-emphasized);");
    expect(root).toContain("--awrad-motion-content-swap-fade-in: var(--awrad-duration-color);");
    expect(root).toContain("--awrad-reduced-motion-duration: var(--awrad-duration-color);");
    expect(root).toContain("--awrad-ease-linear: cubic-bezier(0, 0, 1, 1);");
    expect(root).toContain("--awrad-motion-content-swap-easing: var(--awrad-ease-linear);");
    expect(root).toContain("--awrad-reduced-motion-easing: var(--awrad-ease-linear);");
    // press (and its pressEasing) and sheet are mobile motions.
    expect(root).not.toContain("--awrad-motion-press");
    expect(root).not.toContain("--awrad-motion-sheet");
    expect(root).not.toContain("page-push");
    expect(root).not.toContain("spring");
    expect(theme).toContain("--ease-*: initial;");
    expect(theme).toContain("--animate-*: initial;");
  });
});

describe("generate-tokens: bad input", () => {
  test.each([
    ["a role with an unknown radius", "shape", (shape) => (shape.roles.card.radius = "huge"), /roles\.card/],
    ["a role with an unknown space", "spacing", (spacing) => (spacing.roles.rowGap.space = "9xl"), /roles\.rowGap/],
    ["a negative size", "spacing", (spacing) => (spacing.sizes.icon.value = -1), /sizes\.icon/],
    ["a weight off the hundreds", "typography", (type) => (type.styles.body.weight = 450), /styles\.body\.weight/],
    [
      "an easing that isn't four numbers",
      "motion",
      (motion) => (motion.easing.emphasized = [0, 1]),
      /easing\.emphasized/,
    ],
    [
      "a web motion naming an unknown duration",
      "motion",
      (motion) => (motion.motions.webPage.fadeIn = "slow"),
      /webPage\.fadeIn/,
    ],
    [
      "a reduced-motion easing that doesn't exist",
      "motion",
      (motion) => (motion.reducedMotion.easing = "bouncy"),
      /reducedMotion\.easing/,
    ],
    ["a negative stroke", "shape", (shape) => (shape.strokes.checkbox.width = -2), /strokes\.checkbox\.width/],
    [
      "a style in a font the web doesn't load",
      "typography",
      (type) => (type.styles.quran.fontFamily = "Amiri"),
      /styles\.quran\.fontFamily/,
    ],
  ])("rejects %s", (_, file, change, message) => {
    expect(() => renderTokensCss(withChange(file, change))).toThrow(message);
  });
});

describe("check-raw-values: tokens", () => {
  test.each([
    ["p-[13px]", "arbitrary value"],
    ["rounded-[10px]", "arbitrary value"],
    ["text-[15px]", "arbitrary value"],
    ["md:w-[42rem]", "arbitrary value"],
    ["p-(--my-space)", "arbitrary value"],
    ["[mask-type:luminance]", "arbitrary value"],
    ["rounded", "radius that isn't a shape token"],
    ["rounded-none", "radius that isn't a shape token"],
    ["rounded-t-huge", "radius that isn't a shape token"],
    ["text-sm", "text size that isn't a text style"],
    ["hover:text-2xl", "text size that isn't a text style"],
    ["leading-tight", "line height or tracking (text styles carry them)"],
    ["tracking-wide", "line height or tracking (text styles carry them)"],
    ["font-black", "font weight that no text style uses"],
    ["p-4", "spacing that isn't a token"],
    ["gap-1.5", "spacing that isn't a token"],
    ["-mt-2", "spacing that isn't a token"],
    ["min-h-11", "spacing that isn't a token"],
    ["size-5", "spacing that isn't a token"],
    ["p-px", "spacing that isn't a token"],
    ["h-12", "spacing that isn't a token"],
    ["min-h-14", "spacing that isn't a token"],
    ["max-w-[28rem]", "arbitrary value"],
    ["max-w-page", "max width that isn't a token"],
    ["max-w-prose", "max width that isn't a token"],
    ["md:max-w-7xl", "max width that isn't a token"],
    ["border", "line width that isn't a stroke token"],
    ["border-2", "line width that isn't a stroke token"],
    ["border-x", "line width that isn't a stroke token"],
    ["border-t-4", "line width that isn't a stroke token"],
    ["border-ss-2", "line width that isn't a stroke token"],
    ["outline", "line width that isn't a stroke token"],
    ["outline-2", "line width that isn't a stroke token"],
    ["focus-visible:outline-offset-2", "line width that isn't a stroke token"],
    ["ring", "line width that isn't a stroke token"],
    ["ring-2", "line width that isn't a stroke token"],
    ["ring-offset-1", "line width that isn't a stroke token"],
    ["divide-y", "line width that isn't a stroke token"],
    ["disabled:opacity-50", "disabled opacity that isn't the state token (opacity-disabled)"],
    ["data-disabled:opacity-40", "disabled opacity that isn't the state token (opacity-disabled)"],
    ["group-disabled:opacity-38", "disabled opacity that isn't the state token (opacity-disabled)"],
    ["animate-spin", "animation class (motion is fades only: motion.css)"],
    ["transition-colors", "animation class (motion is fades only: motion.css)"],
    ["duration-150", "animation class (motion is fades only: motion.css)"],
    ["ease-in-out", "animation class (motion is fades only: motion.css)"],
  ])("flags %s", (candidate, problem) => {
    expect(classProblem(candidate, vocab)).toBe(problem);
  });
});

describe("check-raw-values: token classes", () => {
  test.each([
    "rounded-card",
    "rounded-t-sheet",
    "rounded-ss-field",
    "rounded-xs",
    "rounded-full",
    "data-pressed:rounded-chip",
    "p-card-padding",
    "px-page-margin",
    "gap-row-gap",
    "gap-inline-gap",
    "py-4xl",
    "-ms-sm",
    "min-h-touch-target",
    "size-icon-small",
    "inset-0",
    "min-w-0",
    "w-full",
    "w-1/2",
    "min-h-dvh",
    "min-h-control",
    "size-logo",
    "max-w-content",
    "max-w-dialog",
    "max-w-full",
    "max-w-none",
    "max-w-1/2",
    "rounded-checkbox",
    "rounded-xxs",
    "rounded-xxxs",
    "border-checkbox",
    "border-field-error",
    "border-transparent",
    "data-invalid:border-error",
    "group-data-focus-visible:outline-focus-ring",
    "outline-offset-focus-ring",
    "outline-accent",
    "outline-none",
    "outline-solid",
    "divide-y-reverse",
    "disabled:opacity-disabled",
    "data-pressed:opacity-90",
    "text-title",
    "text-body-small",
    "text-input",
    "text-quran",
    "text-counter",
    "text-on-surface",
    "text-on-surface/40",
    "text-error!",
    "text-start",
    "font-semibold",
    "font-arabic",
    "tabular-nums",
    "content-swap",
    "page-transition",
  ])("allows %s", (candidate) => {
    expect(classProblem(candidate, vocab)).toBeNull();
  });
});

describe("check-raw-values: where it looks", () => {
  test("reads classes from string literals in code, not comments or other text", () => {
    expect(rawValues('<p className="rounded-xl p-4 text-sm">', "code")).toEqual([
      '1: spacing that isn\'t a token "p-4"',
      '1: text size that isn\'t a text style "text-sm"',
    ]);
    expect(rawValues("const c = `content-swap px-4 ${fill}`;", "code")).toEqual([
      '1: spacing that isn\'t a token "px-4"',
    ]);
    expect(rawValues("// a rounded corner, p-4 apart", "code")).toEqual([]);
    expect(rawValues('t("account.devices.platform.web")', "code")).toEqual([]);
  });

  test("checks @apply and raw motion and lengths in hand-written CSS", () => {
    expect(rawValues("  @apply text-sm rounded-card;", "css")).toEqual([
      '1: text size that isn\'t a text style "text-sm"',
    ]);
    expect(rawValues("  animation: fade 150ms ease;", "css")).toEqual([
      '1: raw duration "150ms"',
      '1: raw easing "animation: fade 150ms ease"',
    ]);
    expect(rawValues("  transition-timing-function: cubic-bezier(0.2, 0, 0, 1);", "css")).toEqual([
      '1: raw easing "cubic-bezier("',
    ]);
    expect(rawValues("  border-radius: 12px;", "css")).toHaveLength(1);
    expect(rawValues("  font-size: 0.875rem;", "css")).toHaveLength(1);
    expect(rawValues("  padding-inline: 4px 8px;", "css")).toHaveLength(1);
    expect(rawValues("  animation: awrad-fade-in var(--awrad-reduced-motion-duration) linear both;", "css")).toEqual([
      '1: raw easing "animation: awrad-fade-in var(--awrad-reduced-motion-duration) linear"',
    ]);
    expect(rawValues("  transition: opacity var(--awrad-duration-fade) ease-out;", "css")).toHaveLength(1);
    expect(
      rawValues(
        "  animation: awrad-fade-in var(--awrad-reduced-motion-duration) var(--awrad-reduced-motion-easing) both;",
        "css",
      ),
    ).toEqual([]);
    expect(rawValues("  animation: awrad-fade-in var(--awrad-duration-fade) var(--awrad-ease-linear);", "css")).toEqual(
      [],
    );
    expect(rawValues("  view-transition-name: page;", "css")).toEqual([]);
    expect(rawValues("  outline: 2px solid --theme(--color-accent);", "css")).toEqual(['1: raw length "outline: 2px"']);
    expect(rawValues("  outline-offset: 2px;", "css")).toHaveLength(1);
    expect(rawValues("  border-width: 1.5px;", "css")).toHaveLength(1);
    expect(rawValues("  border-inline-start: 1px solid;", "css")).toHaveLength(1);
    expect(rawValues("  outline: var(--awrad-stroke-focus-ring) solid --theme(--color-accent);", "css")).toEqual([]);
    expect(rawValues("  font-weight: 400;", "css")).toEqual([]);
  });
});
