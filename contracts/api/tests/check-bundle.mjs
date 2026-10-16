// Fails when api/openapi.bundled.json is stale relative to the multi-file source.
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../..", import.meta.url));
const dir = mkdtempSync(join(tmpdir(), "awrad-bundle-"));
try {
  const fresh = join(dir, "openapi.bundled.json");
  execFileSync("node_modules/.bin/redocly", ["bundle", "api/openapi.yaml", "-o", fresh], {
    cwd: root,
    stdio: "ignore",
    env: { ...process.env, REDOCLY_TELEMETRY: "off", REDOCLY_SUPPRESS_UPDATE_NOTICE: "true" },
  });
  const committed = readFileSync(join(root, "api/openapi.bundled.json"), "utf8");
  if (readFileSync(fresh, "utf8") !== committed) {
    console.error("api/openapi.bundled.json is stale. Run: npm run bundle");
    process.exit(1);
  }
  console.log("bundle: api/openapi.bundled.json is up to date");
} finally {
  rmSync(dir, { recursive: true, force: true });
}
