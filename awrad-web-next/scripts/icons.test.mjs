// The icon pipeline: contracts/design-tokens/v1/icons.json and icons/*.svg → icons.gen.tsx.
import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { TARGET, componentName, pathData, readIcons, renderIconsTsx, resolveIcons } from "./generate-icons.mjs";

const source = readIcons();
const tsx = await renderIconsTsx(source);

/** icons.json with a change, and the same SVGs. */
function withChange(change) {
  const json = structuredClone(source.json);
  change(json);
  return { json, files: source.files };
}

/** The generated component for `name`. */
function component(text, name) {
  const start = text.indexOf(`export function ${componentName(name)}(`);
  return text.slice(start, text.indexOf("\n}\n", start));
}

describe("icons.gen.tsx", () => {
  test("is the committed file", () => {
    expect(readFileSync(TARGET, "utf8")).toBe(tsx);
  });

  test("has one component per icon name, every path, on the 960 grid, in currentColor and aria-hidden", () => {
    for (const [name, { file }] of Object.entries(source.json.icons)) {
      expect(tsx).toContain(`export function ${componentName(name)}(props: IconProps): ReactElement {`);
      for (const d of pathData(file, source.files[file])) expect(component(tsx, name)).toContain(JSON.stringify(d));
    }
    expect(componentName("forward")).toBe("ForwardIcon");
    expect(tsx).toContain('viewBox="0 -960 960 960"');
    expect(tsx).toContain('fill="currentColor"');
    expect(tsx).toContain('aria-hidden="true"');
    expect(tsx).toContain('"size-icon"');
    expect(tsx).toContain('"size-icon-small"');
  });

  test("only mirrorInRtl icons flip in right-to-left layouts", () => {
    expect(tsx).toContain('mirrorInRtl && "rtl:-scale-x-100"');
    for (const [name, { mirrorInRtl }] of Object.entries(source.json.icons)) {
      if (mirrorInRtl) expect(component(tsx, name)).toContain("mirrorInRtl");
      else expect(component(tsx, name)).not.toContain("mirrorInRtl");
    }
    expect(component(tsx, "back")).toContain("mirrorInRtl");
    expect(component(tsx, "forward")).toContain("mirrorInRtl");
  });

  test("follows icons.json: a newly mirrored icon flips", async () => {
    const changed = await renderIconsTsx(withChange((json) => (json.icons.more.mirrorInRtl = true)));
    expect(component(changed, "more")).toContain("mirrorInRtl");
  });
});

describe("generate-icons failures", () => {
  test("an unknown top-level or icon key fails", () => {
    expect(() => resolveIcons(withChange((json) => (json.sizes = {})))).toThrow(/unknown key "sizes"/);
    expect(() => resolveIcons(withChange((json) => (json.icons.back.filled = true)))).toThrow(
      /icons\.back: unknown key "filled"/,
    );
  });

  test("mirrorInRtl is required, the file must exist, and names are camelCase", () => {
    expect(() => resolveIcons(withChange((json) => delete json.icons.back.mirrorInRtl))).toThrow(/mirrorInRtl/);
    expect(() => resolveIcons(withChange((json) => (json.icons.back.file = "nope.svg")))).toThrow(/nope\.svg/);
    expect(() =>
      resolveIcons(withChange((json) => (json.icons["go-back"] = { file: "chevron_left.svg", mirrorInRtl: true }))),
    ).toThrow(/camelCase/);
  });

  test("only plain path-only SVGs on the 960 grid", () => {
    const svg = (body, viewBox = "0 -960 960 960") =>
      `<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="${viewBox}" width="24">${body}</svg>`;
    expect(pathData("a.svg", svg('<path d="M0 0h1"/><path d="M2 2h1"/>'))).toEqual(["M0 0h1", "M2 2h1"]);
    expect(() => pathData("a.svg", svg('<path d="M0 0h1"/>', "0 0 24 24"))).toThrow(/viewBox/);
    expect(() => pathData("a.svg", svg('<circle r="1"/>'))).toThrow(/<circle> isn't allowed/);
    expect(() => pathData("a.svg", svg('<path fill-rule="evenodd" d="M0 0h1"/>'))).toThrow(/no other attributes/);
    expect(() => pathData("a.svg", svg(""))).toThrow(/no <path>/);
  });
});
