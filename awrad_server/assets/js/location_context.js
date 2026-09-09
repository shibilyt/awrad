export function locationFromDataset(dataset) {
  const latitude = Number(dataset.locationLatitude)
  const longitude = Number(dataset.locationLongitude)

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null

  const locationName = String(dataset.locationName || "").trim()

  return {
    latitude,
    longitude,
    ...(locationName ? {location_name: locationName} : {}),
    location_source: dataset.locationSource || "browser"
  }
}

export function locationFingerprint(dataset) {
  return [
    dataset.locationLatitude || "",
    dataset.locationLongitude || "",
    dataset.locationName || "",
    dataset.locationSource || ""
  ].join("|")
}

export function withLocationName(location, locationName) {
  const normalizedName = String(locationName || "").trim()

  return normalizedName
    ? {...location, location_name: normalizedName}
    : {...location}
}
