import { useState } from "react";

/**
 * Where this browser is, for Maghrib (practice-settings.schema.json `location`): device context,
 * never sent to the server (root ADR-2026-10-29). The web keeps it in browser storage per
 * account, so another account in the same browser doesn't inherit it.
 */
export interface DeviceLocation {
  latitude: number;
  longitude: number;
  /** The city's name, or `null` for the browser's own reading. */
  name: string | null;
  /** The web has `gps` (the browser's location) and `city` (the bundled list); `search` is the phones'. */
  source: "gps" | "city" | "search";
  /** The bundled city's GeoNames ID when `source` is `city`. */
  city_id: number | null;
}

const PREFIX = "awrad.location.";

function storageKey(accountId: string): string {
  return `${PREFIX}${accountId}`;
}

const isNumberIn = (value: unknown, limit: number): value is number =>
  typeof value === "number" && Number.isFinite(value) && Math.abs(value) <= limit;

/** A stored value that is a location; anything else (an older shape, a hand edit) counts as none. */
function asLocation(value: unknown): DeviceLocation | null {
  if (typeof value !== "object" || value === null) return null;
  const { latitude, longitude, name, source, city_id: cityId } = value as Record<string, unknown>;
  if (!isNumberIn(latitude, 90) || !isNumberIn(longitude, 180)) return null;
  if (name !== null && typeof name !== "string") return null;
  if (source !== "gps" && source !== "city" && source !== "search") return null;
  if (cityId !== null && !(typeof cityId === "number" && Number.isInteger(cityId))) return null;
  return { latitude, longitude, name, source, city_id: cityId };
}

/** The location this browser keeps for an account, or `null`. Storage can be unavailable (privacy modes). */
export function storedLocation(accountId: string): DeviceLocation | null {
  try {
    const text = window.localStorage.getItem(storageKey(accountId));
    return text === null ? null : asLocation(JSON.parse(text));
  } catch {
    return null;
  }
}

/** Keeps (or, with `null`, forgets) this browser's location for an account. */
export function storeLocation(accountId: string, location: DeviceLocation | null): void {
  try {
    if (location === null) window.localStorage.removeItem(storageKey(accountId));
    else window.localStorage.setItem(storageKey(accountId), JSON.stringify(location));
  } catch {
    // Kept for this page only.
  }
}

/** The account's location in this browser, and a setter that keeps it there. */
export function useDeviceLocation(
  accountId: string,
): [DeviceLocation | null, (location: DeviceLocation | null) => void] {
  const [location, setLocation] = useState(() => storedLocation(accountId));
  const update = (next: DeviceLocation | null): void => {
    storeLocation(accountId, next);
    setLocation(next);
  };
  return [location, update];
}

/** One coarse reading of the browser's location ("Use my location"), as a device location. */
export function readBrowserLocation(): Promise<DeviceLocation> {
  return new Promise((resolve, reject: (error: GeolocationPositionError | Error) => void) => {
    if (!("geolocation" in navigator)) {
      reject(new Error("geolocation unavailable"));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        resolve({ latitude: coords.latitude, longitude: coords.longitude, name: null, source: "gps", city_id: null });
      },
      reject,
      { enableHighAccuracy: false, maximumAge: 600_000, timeout: 20_000 },
    );
  });
}
