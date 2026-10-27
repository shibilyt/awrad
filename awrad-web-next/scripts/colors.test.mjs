// The colour pipeline: contracts/design-tokens/v1/colors.json → colors.gen.css → Tailwind roles.
import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { rawValues } from "./check-raw-values.mjs";
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
    // One colour per role in each scheme, and nothing else: `states` are opacities, not colours.
    expect(Object.keys(tokens)).toContain("states");
    expect(Object.keys(tokens.roles)).not.toContain("disabled");
    expect(light.match(/--awrad-color-[\w-]+:/g)).toHaveLength(roles.length);
    expect(dark.match(/--awrad-color-[\w-]+:/g)).toHaveLength(roles.length);
    expect(css).not.toMatch(/--(?:awrad-)?color-(?:states|disabled)/);
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

  test("draws states at their opacity: a property and an opacity-<state> class, outside the theme", () => {
    const states = css.slice(css.indexOf("/* States"));
    expect(tokens.states.disabled.opacity).toBe(0.38);
    expect(states).toContain(":root {\n  --awrad-state-disabled-opacity: 0.38;\n}");
    expect(states).toContain("@utility opacity-disabled {\n  opacity: var(--awrad-state-disabled-opacity);\n}");
    expect(css.indexOf("/* States")).toBeGreaterThan(css.indexOf("@theme inline"));
    expect(theme.split("}")[0]).not.toContain("disabled");
  });

  test("works without states, and rejects an opacity outside 0…1", () => {
    const withoutStates = structuredClone(tokens);
    delete withoutStates.states;
    expect(renderColorsCss(withoutStates)).not.toContain("--awrad-state-");
    expect(() => renderColorsCss({ ...tokens, states: { disabled: { opacity: 38, use: "" } } })).toThrow(
      /states\.disabled\.opacity/,
    );
  });

  test("rejects a value that isn't #RRGGBB or #RRGGBBAA", () => {
    expect(() => renderColorsCss({ roles: { accent: { light: "#fff", dark: "#B7D6B6" } } })).toThrow(/accent\.light/);
  });
});

describe("check-raw-values: colours", () => {
  test.each([
    'className="text-white"',
    'className="hover:bg-red-500/50"',
    'className="border-x-slate-200"',
    'className="bg-[#23553C]"',
    "color: #fff;",
    "color: rgb(0 0 0 / 0.5);",
    "--x: light-dark(#ffffff, #000000);",
  ])("flags %s", (line) => {
    expect(rawValues(line, "code")).not.toHaveLength(0);
  });

  test.each([
    'className="bg-surface text-on-surface border-outline-strong text-accent text-label text-error!"',
    'className="bg-on-surface/40 divide-outline focus-ring"',
    'document.getElementById("root") ?? "#root"',
    "color: color-mix(in oklab, var(--color-accent) 50%, transparent);",
  ])("allows %s", (line) => {
    expect(rawValues(line, "code")).toEqual([]);
  });
});
