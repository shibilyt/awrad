import { describe, expect, test } from "vitest";
import { allowedOffsets, monthStart, offsetFor, withMonthOffset, withoutCorrection } from "./hijri";
import { storeLocation, storedLocation } from "./location";

// Beyond the shared fixtures: what "Adjust this month" offers, and the browser's own location.
describe("adjusting a month", () => {
  test("a month after a 30-day month can only start earlier; one after a 29-day month only later", () => {
    // Rabi' al-Thani 1448 has 30 days, so Jumada al-Ula can't start later.
    expect(allowedOffsets([], 1448, 5)).toEqual([-1, 0]);
    // Rabi' al-Awwal 1448 has 29 days, so Rabi' al-Thani can only start later.
    expect(allowedOffsets([], 1448, 4)).toEqual([0, 1]);
  });

  test("two days takes two months in a row", () => {
    const first = withMonthOffset([], 1446, 12, 1);
    expect(allowedOffsets(first, 1447, 1)).toContain(2);
    expect(allowedOffsets([], 1447, 1)).not.toContain(2);
  });

  test("an offset the earlier months already carry needs no correction of its own", () => {
    const corrections = [{ year: 1447, month: 9, offset_days: 1 }];
    expect(offsetFor(corrections, 1447, 11)).toBe(1);
    expect(withMonthOffset(corrections, 1447, 11, 1)).toEqual(corrections);
    expect(withMonthOffset(corrections, 1447, 11, 0)).toEqual([
      { year: 1447, month: 9, offset_days: 1 },
      { year: 1447, month: 11, offset_days: 0 },
    ]);
    expect(withoutCorrection(corrections, 1447, 9)).toEqual([]);
  });

  test("a month's first day moves with its offset", () => {
    expect(monthStart(1448, 5, 0)).toBe("2026-10-12");
    expect(monthStart(1448, 5, -1)).toBe("2026-10-11");
    expect(monthStart(1501, 1, 0)).toBeNull();
  });
});

describe("the browser's location", () => {
  const ACCOUNT = "0192f000-0000-7000-8000-000000000001";

  test("is kept per account", () => {
    const location = { latitude: 21.4225, longitude: 39.8262, name: "Mecca", source: "city", city_id: 104515 } as const;
    storeLocation(ACCOUNT, location);
    expect(storedLocation(ACCOUNT)).toEqual(location);
    expect(storedLocation("0192f000-0000-7000-8000-000000000002")).toBeNull();
    storeLocation(ACCOUNT, null);
    expect(storedLocation(ACCOUNT)).toBeNull();
  });

  test("a stored value that isn't a location counts as none", () => {
    window.localStorage.setItem(`awrad.location.${ACCOUNT}`, JSON.stringify({ latitude: 95, longitude: 0 }));
    expect(storedLocation(ACCOUNT)).toBeNull();
    window.localStorage.setItem(`awrad.location.${ACCOUNT}`, "not json");
    expect(storedLocation(ACCOUNT)).toBeNull();
  });
});
