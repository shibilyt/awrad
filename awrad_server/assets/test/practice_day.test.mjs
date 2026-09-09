import assert from "node:assert/strict"
import test from "node:test"

import {resolvePracticeDay, resolvePrayerTimes} from "../js/practice_day.js"

const base = {
  timeZone: "Asia/Kolkata",
  latitude: 12.9716,
  longitude: 77.5946,
  calculationMethod: "karachi",
  madhab: "shafi"
}

test("midnight reset uses the browser civil date", () => {
  const result = resolvePracticeDay({
    ...base,
    now: new Date("2026-09-09T12:00:00.000Z"),
    dayReset: "midnight"
  })

  assert.equal(result.civilDate, "2026-09-09")
  assert.equal(result.effectiveDate, "2026-09-09")
  assert.equal(result.status, "midnight")
  assert.equal(result.maghribAt, null)
})

test("Maghrib reset advances after the calculated sunset", () => {
  const before = resolvePracticeDay({
    ...base,
    now: new Date("2026-09-09T12:00:00.000Z"),
    dayReset: "maghrib"
  })

  const after = resolvePracticeDay({
    ...base,
    now: new Date("2026-09-09T16:00:00.000Z"),
    dayReset: "maghrib"
  })

  assert.equal(before.civilDate, "2026-09-09")
  assert.equal(before.effectiveDate, "2026-09-09")
  assert.equal(before.status, "maghrib")
  assert.equal(after.civilDate, "2026-09-09")
  assert.equal(after.effectiveDate, "2026-09-10")
  assert.equal(after.status, "maghrib")
  assert.match(after.maghribAt, /T/)
})

test("Maghrib reset safely falls back when location is missing", () => {
  const result = resolvePracticeDay({
    timeZone: "Asia/Kolkata",
    now: new Date("2026-09-09T16:00:00.000Z"),
    dayReset: "maghrib"
  })

  assert.equal(result.civilDate, "2026-09-09")
  assert.equal(result.effectiveDate, "2026-09-09")
  assert.equal(result.status, "location_required")
  assert.equal(result.maghribAt, null)
})

test("calculates the mobile-style prayer list for Koyilandy", () => {
  const result = resolvePrayerTimes({
    civilDate: "2026-09-09",
    now: new Date("2026-09-09T07:00:00.000Z"),
    timeZone: "Asia/Kolkata",
    latitude: 11.4408,
    longitude: 75.6954,
    calculationMethod: "karachi",
    madhab: "shafi"
  })

  assert.equal(result.status, "ready")
  assert.deepEqual(
    result.prayers.map(prayer => prayer.name),
    ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
  )
  assert.ok(result.prayers.every(prayer => /^(?:\d{1,2}):\d{2} [AP]M$/.test(prayer.time)))
  assert.equal(result.nextPrayer.name, "Asr")
  assert.match(result.nextPrayer.countdown, /^in \d+h \d+m$/)
  assert.equal(result.prayers.filter(prayer => prayer.is_next).length, 1)
  assert.equal(result.prayers.find(prayer => prayer.name === "Fajr").is_complete, true)
})

test("does not expose prayer times without a selected location", () => {
  const result = resolvePrayerTimes({
    civilDate: "2026-09-09",
    now: new Date("2026-09-09T07:00:00.000Z"),
    timeZone: "Asia/Kolkata"
  })

  assert.equal(result.status, "location_required")
  assert.deepEqual(result.prayers, [])
  assert.equal(result.nextPrayer, null)
})
