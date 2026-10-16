// The fixture checker must accept every file in fixtures-good/ and reject every file in fixtures-bad/.
import { readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { checkFixtureFile } from "../check-fixtures.mjs";

const here = fileURLToPath(new URL(".", import.meta.url));
let failed = false;
for (const [dir, shouldPass] of [["fixtures-good", true], ["fixtures-bad", false]]) {
  for (const name of readdirSync(join(here, dir))) {
    const problems = checkFixtureFile(join(here, dir, name)) ?? ["not recognised as awrad-fixture/1"];
    if ((problems.length === 0) !== shouldPass) {
      failed = true;
      console.error(`${dir}/${name}: expected ${shouldPass ? "valid" : "invalid"}; problems: ${problems.join("; ") || "none"}`);
    }
  }
}
if (failed) process.exit(1);
console.log("fixture format: checker accepts good files and rejects all bad files");
