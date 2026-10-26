import { describe, expect, test } from "vitest";
import { emailCodeInput, emailInput, passwordErrors } from ".";

/**
 * Runs contracts/account-model/v1/fixtures/ (contracts/FIXTURES.md) against the
 * real rules, naming failures by case id. Every fixture file there needs an
 * adapter here, so a new shared rule can't be skipped silently.
 */
interface Fixture {
  format: string;
  rule: string;
  cases: { id: string; given: Record<string, unknown>; expect: unknown }[];
}

const FIXTURES: Record<string, Fixture> = import.meta.glob("../../../../contracts/account-model/v1/fixtures/*.json", {
  eager: true,
  import: "default",
});

function text(given: Record<string, unknown>, key: string): string {
  const value = given[key];
  if (typeof value !== "string") throw new Error(`given.${key} isn't a string`);
  return value;
}

const ADAPTERS: Record<string, (given: Record<string, unknown>) => unknown> = {
  email_input: (given) => {
    const email = emailInput(text(given, "input"));
    return { valid: email !== null, email };
  },
  password_policy: (given) => {
    const errors = passwordErrors(text(given, "password"));
    return { valid: errors.length === 0, errors };
  },
  email_code_input: (given) => ({ code: emailCodeInput(text(given, "input")) }),
};

const fixtures = Object.entries(FIXTURES)
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([, fixture]) => fixture);

test("every account-model fixture file has an adapter, and every adapter a fixture file", () => {
  expect(fixtures.length).toBeGreaterThan(0);
  expect(fixtures.map((fixture) => fixture.rule).sort()).toEqual(Object.keys(ADAPTERS).sort());
  for (const fixture of fixtures) expect(fixture.format).toBe("awrad-fixture/1");
});

for (const fixture of fixtures) {
  describe(fixture.rule, () => {
    test.each(fixture.cases.map((testCase) => [testCase.id, testCase] as const))("%s", (_id, testCase) => {
      const adapter = ADAPTERS[fixture.rule];
      if (adapter === undefined) throw new Error(`no adapter for ${fixture.rule}`);
      expect(adapter(testCase.given)).toEqual(testCase.expect);
    });
  });
}
