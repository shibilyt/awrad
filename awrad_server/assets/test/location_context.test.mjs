import assert from "node:assert/strict"
import test from "node:test"

import {locationFingerprint, locationFromDataset, withLocationName} from "../js/location_context.js"

test("reads a saved human location name alongside calculation coordinates", () => {
  const location = locationFromDataset({
    locationLatitude: "12.9716",
    locationLongitude: "77.5946",
    locationName: "Bengaluru, Karnataka, India",
    locationSource: "manual"
  })

  assert.deepEqual(location, {
    latitude: 12.9716,
    longitude: 77.5946,
    location_name: "Bengaluru, Karnataka, India",
    location_source: "manual"
  })
  assert.equal(
    locationFingerprint({
      locationLatitude: "12.9716",
      locationLongitude: "77.5946",
      locationName: "Bengaluru, Karnataka, India",
      locationSource: "manual"
    }),
    "12.9716|77.5946|Bengaluru, Karnataka, India|manual"
  )
})

test("adds a reverse-geocoded name without changing the coordinates", () => {
  assert.deepEqual(
    withLocationName(
      {latitude: 12.9716, longitude: 77.5946, location_source: "browser"},
      "Bengaluru, Karnataka, India"
    ),
    {
      latitude: 12.9716,
      longitude: 77.5946,
      location_name: "Bengaluru, Karnataka, India",
      location_source: "browser"
    }
  )
})
