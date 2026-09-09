import {CalculationMethod, Coordinates, Madhab, PrayerTimes} from "adhan"

const calculationMethods = {
  karachi: () => CalculationMethod.Karachi(),
  north_america: () => CalculationMethod.NorthAmerica(),
  mwl: () => CalculationMethod.MuslimWorldLeague(),
  egypt: () => CalculationMethod.Egyptian(),
  umm_al_qura: () => CalculationMethod.UmmAlQura(),
  moon_sighting: () => CalculationMethod.MoonsightingCommittee(),
  dubai: () => CalculationMethod.Dubai(),
  kuwait: () => CalculationMethod.Kuwait(),
  qatar: () => CalculationMethod.Qatar(),
  singapore: () => CalculationMethod.Singapore()
}

const homePrayerDefinitions = [
  ["fajr", "Fajr"],
  ["dhuhr", "Dhuhr"],
  ["asr", "Asr"],
  ["maghrib", "Maghrib"],
  ["isha", "Isha"]
]

export function resolvePracticeDay({
  now = new Date(),
  timeZone = "UTC",
  latitude,
  longitude,
  dayReset = "midnight",
  calculationMethod = "karachi",
  madhab = "shafi"
} = {}) {
  const civilDate = browserCivilDate(now, timeZone)

  if (dayReset !== "maghrib") {
    return {civilDate, effectiveDate: civilDate, maghribAt: null, status: "midnight"}
  }

  if (!validCoordinates(latitude, longitude)) {
    return {civilDate, effectiveDate: civilDate, maghribAt: null, status: "location_required"}
  }

  try {
    const method = calculationMethods[calculationMethod]
    if (!method) throw new Error("unsupported calculation method")

    const parameters = method()
    parameters.madhab = madhab === "hanafi" ? Madhab.Hanafi : Madhab.Shafi

    const coordinates = new Coordinates(Number(latitude), Number(longitude))
    const prayerDate = localNoonFor(civilDate)
    const maghrib = new PrayerTimes(coordinates, prayerDate, parameters).maghrib

    if (!(maghrib instanceof Date) || Number.isNaN(maghrib.getTime())) {
      throw new Error("Maghrib is unavailable for this location")
    }

    const effectiveDate = now.getTime() >= maghrib.getTime()
      ? addCalendarDays(civilDate, 1)
      : civilDate

    return {
      civilDate,
      effectiveDate,
      maghribAt: maghrib.toISOString(),
      status: "maghrib"
    }
  } catch (_error) {
    return {
      civilDate,
      effectiveDate: civilDate,
      maghribAt: null,
      status: "calculation_unavailable"
    }
  }
}

export function resolvePrayerTimes({
  now = new Date(),
  timeZone = "UTC",
  civilDate = browserCivilDate(now, timeZone),
  latitude,
  longitude,
  calculationMethod = "karachi",
  madhab = "shafi"
} = {}) {
  if (!validCoordinates(latitude, longitude)) {
    return {civilDate, prayers: [], nextPrayer: null, status: "location_required"}
  }

  try {
    const method = calculationMethods[calculationMethod]
    if (!method) throw new Error("unsupported calculation method")

    const parameters = method()
    parameters.madhab = madhab === "hanafi" ? Madhab.Hanafi : Madhab.Shafi

    const coordinates = new Coordinates(Number(latitude), Number(longitude))
    const prayerTimes = new PrayerTimes(coordinates, localNoonFor(civilDate), parameters)
    const rows = homePrayerDefinitions
      .map(([key, name]) => ({key, name, at: prayerTimes[key]}))
      .filter(({at}) => at instanceof Date && !Number.isNaN(at.getTime()))

    const next = rows.find(({at}) => at.getTime() > now.getTime())
    const prayers = rows.map(row => ({
      name: row.name,
      at: row.at.toISOString(),
      time: formatPrayerTime(row.at, timeZone),
      is_complete: next ? row.at.getTime() < next.at.getTime() : true,
      is_next: next?.key === row.key
    }))

    const nextPrayer = next && {
      name: next.name,
      at: next.at.toISOString(),
      time: formatPrayerTime(next.at, timeZone),
      countdown: formatCountdown(now, next.at)
    }

    return {
      civilDate,
      prayers,
      nextPrayer: nextPrayer || null,
      status: "ready"
    }
  } catch (_error) {
    return {civilDate, prayers: [], nextPrayer: null, status: "calculation_unavailable"}
  }
}

export function browserCivilDate(now, timeZone) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  })

  const parts = Object.fromEntries(
    formatter.formatToParts(now).map(({type, value}) => [type, value])
  )

  return `${parts.year}-${parts.month}-${parts.day}`
}

function localNoonFor(civilDate) {
  const [year, month, day] = civilDate.split("-").map(Number)
  return new Date(year, month - 1, day, 12, 0, 0, 0)
}

function addCalendarDays(civilDate, days) {
  const date = new Date(`${civilDate}T12:00:00Z`)
  date.setUTCDate(date.getUTCDate() + days)
  return date.toISOString().slice(0, 10)
}

function formatPrayerTime(date, timeZone) {
  return new Intl.DateTimeFormat("en-US", {
    timeZone,
    hour: "numeric",
    minute: "2-digit"
  }).format(date)
}

function formatCountdown(now, target) {
  const totalMinutes = Math.max(Math.floor((target.getTime() - now.getTime()) / (1000 * 60)), 0)
  const hours = Math.floor(totalMinutes / 60)
  const minutes = totalMinutes % 60
  return hours > 0 ? `in ${hours}h ${minutes}m` : `in ${minutes}m`
}

function validCoordinates(latitude, longitude) {
  return Number.isFinite(Number(latitude)) &&
    Number.isFinite(Number(longitude)) &&
    Number(latitude) >= -90 && Number(latitude) <= 90 &&
    Number(longitude) >= -180 && Number(longitude) <= 180
}
