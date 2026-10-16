// Proves the ruleset works in both directions:
//   1. the real (bundled) spec has no findings at all;
//   2. the violations fixture trips every custom awrad-* rule.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../..", import.meta.url));
const ruleset = "api/spectral.mjs";
const spectral = "node_modules/.bin/spectral";

function lint(file) {
  try {
    const out = execFileSync(spectral, ["lint", file, "--ruleset", ruleset, "--format", "json", "--quiet"], {
      cwd: root,
      encoding: "utf8",
    });
    return JSON.parse(out || "[]");
  } catch (error) {
    // Spectral exits non-zero when it finds problems; the JSON is still on stdout.
    if (error.stdout) return JSON.parse(error.stdout || "[]");
    throw error;
  }
}

let failed = false;

const real = lint("api/openapi.bundled.json");
if (real.length > 0) {
  failed = true;
  console.error(`api/openapi.bundled.json has ${real.length} finding(s):`);
  for (const r of real) console.error(`  ${r.code}: ${r.message} at ${r.path.join(".")}`);
}

const source = readFileSync(new URL("../spectral.mjs", import.meta.url), "utf8");
const customRules = [...source.matchAll(/"(awrad-[a-z0-9-]+)":/g)].map((m) => m[1]);
const fired = new Set(lint("api/tests/violations.yaml").map((r) => r.code));
const silent = customRules.filter((rule) => !fired.has(rule));
if (silent.length > 0) {
  failed = true;
  console.error(`Rules that didn't fire on api/tests/violations.yaml: ${silent.join(", ")}`);
}

if (failed) process.exit(1);
console.log(`spectral: bundled spec clean; all ${customRules.length} awrad rules fire on the violations fixture`);
