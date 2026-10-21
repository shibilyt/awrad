// Fails when src/shared/api/schema.gen.ts is stale relative to contracts/api/openapi.bundled.json.
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const dir = mkdtempSync(join(tmpdir(), "awrad-web-types-"));
try {
  const fresh = join(dir, "schema.gen.ts");
  execFileSync("node_modules/.bin/openapi-typescript", ["../contracts/api/openapi.bundled.json", "-o", fresh], {
    stdio: "ignore",
  });
  if (readFileSync(fresh, "utf8") !== readFileSync("src/shared/api/schema.gen.ts", "utf8")) {
    console.error("src/shared/api/schema.gen.ts is stale. Run: npm run api:types");
    process.exit(1);
  }
  console.log("api types: up to date with contracts/api/openapi.bundled.json");
} finally {
  rmSync(dir, { recursive: true, force: true });
}
