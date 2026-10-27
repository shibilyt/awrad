// The shape, spacing, type and motion pipeline: contracts/design-tokens/v1 → tokens.gen.css
// → Tailwind names, and the check that keeps raw values out of the app.
import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { classProblem, rawValues, vocabulary } from "./check-raw-values.mjs";
import { SOURCE as COLORS, kebab } from "./generate-colors.mjs";
import { TARGET, readTokens, renderTokensCss, tokenNames } from "./generate-tokens.mjs";

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

describe("tokens.gen.css", () => {
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
    expect(theme).not.toMatch(/--spacing:/);
  });

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
    ["animate-spin", "animation class (motion is fades only: motion.css)"],
    ["transition-colors", "animation class (motion is fades only: motion.css)"],
    ["duration-150", "animation class (motion is fades only: motion.css)"],
    ["ease-in-out", "animation class (motion is fades only: motion.css)"],
  ])("flags %s", (candidate, problem) => {
    expect(classProblem(candidate, vocab)).toBe(problem);
  });

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
    "max-w-page",
    "text-title",
    "text-body-small",
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
    "border-2",
    "outline-offset-2",
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
    expect(rawValues("  animation: fade 150ms ease;", "css")).toEqual(['1: raw duration "150ms"']);
    expect(rawValues("  transition-timing-function: cubic-bezier(0.2, 0, 0, 1);", "css")).toEqual([
      '1: raw easing "cubic-bezier("',
    ]);
    expect(rawValues("  border-radius: 12px;", "css")).toHaveLength(1);
    expect(rawValues("  font-size: 0.875rem;", "css")).toHaveLength(1);
    expect(rawValues("  padding-inline: 4px 8px;", "css")).toHaveLength(1);
    expect(rawValues("  animation: awrad-fade-in var(--awrad-reduced-motion-duration) linear both;", "css")).toEqual(
      [],
    );
    expect(rawValues("  outline: 2px solid --theme(--color-accent);", "css")).toEqual([]);
    expect(rawValues("  font-weight: 400;", "css")).toEqual([]);
  });
});
