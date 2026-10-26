// The colour pipeline: contracts/design-tokens/v1/colors.json → colors.gen.css → Tailwind roles.
import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { rawColors } from "./check-raw-colors.mjs";
import { SOURCE, TARGET, kebab, renderColorsCss } from "./generate-colors.mjs";

const tokens = JSON.parse(readFileSync(SOURCE, "utf8"));
const roles = Object.entries(tokens.roles);
const css = renderColorsCss(tokens);
const [light = "", rest = ""] = css.split("@media (prefers-color-scheme: dark)");
const [dark = "", theme = ""] = rest.split("@theme inline");

describe("colors.gen.css", () => {
  test("is the committed file", () => {
    expect(readFileSync(TARGET, "utf8")).toBe(css);
  });

  test("has every role, light in :root and dark under prefers-color-scheme, alpha kept", () => {
    expect(roles).toHaveLength(15);
    expect(light).toContain(":root {");
    for (const [role, value] of roles) {
      expect(light).toContain(`--awrad-color-${kebab(role)}: ${value.light};`);
      expect(dark).toContain(`--awrad-color-${kebab(role)}: ${value.dark};`);
    }
    expect(light).toContain("--awrad-color-on-surface-variant: #000000A6;");
    expect(dark).toContain("--awrad-color-outline-strong: #E3E5E380;");
  });

  test("names every role in Tailwind and removes the default palette", () => {
    expect(theme).toContain("--color-*: initial;");
    for (const [role] of roles) expect(theme).toContain(`--color-${kebab(role)}: var(--awrad-color-${kebab(role)});`);
    expect(kebab("onPrimaryContainer")).toBe("on-primary-container");
  });

  test("rejects a value that isn't #RRGGBB or #RRGGBBAA", () => {
    expect(() => renderColorsCss({ roles: { accent: { light: "#fff", dark: "#B7D6B6" } } })).toThrow(/accent\.light/);
  });
});

describe("check-raw-colors", () => {
  test.each([
    'className="text-white"',
    'className="hover:bg-red-500/50"',
    'className="border-x-slate-200"',
    'className="bg-[#23553C]"',
    "color: #fff;",
    "color: rgb(0 0 0 / 0.5);",
    "--x: light-dark(#ffffff, #000000);",
  ])("flags %s", (line) => {
    expect(rawColors(line)).not.toHaveLength(0);
  });

  test.each([
    'className="bg-surface text-on-surface border-outline-strong text-accent text-sm text-error!"',
    'className="bg-on-surface/40 divide-outline focus-ring"',
    'document.getElementById("root") ?? "#root"',
    "color: color-mix(in oklab, var(--color-accent) 50%, transparent);",
  ])("allows %s", (line) => {
    expect(rawColors(line)).toEqual([]);
  });
});
