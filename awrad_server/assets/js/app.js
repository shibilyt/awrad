import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {resolvePracticeDay, resolvePrayerTimes} from "./practice_day"
import {
  locationFingerprint as datasetLocationFingerprint,
  locationFromDataset,
  withLocationName
} from "./location_context"

const Hooks = {}

Hooks.BrowserClock = {
  mounted() {
    this.lastLocation = this.locationFromElement()
    this.serverLocationFingerprint = this.locationFingerprint()
    this.policyFingerprint = this.currentPolicyFingerprint()
    this.requestBrowserLocation = this.requestBrowserLocation.bind(this)

    this.pushBrowserContext = () => {
      const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC"
      const now = new Date()
      const practiceDay = resolvePracticeDay({
        now,
        timeZone,
        latitude: this.lastLocation?.latitude,
        longitude: this.lastLocation?.longitude,
        dayReset: this.el.dataset.dayReset || "midnight",
        calculationMethod: this.el.dataset.calculationMethod || "karachi",
        madhab: this.el.dataset.madhab || "shafi"
      })
      const prayerTimes = resolvePrayerTimes({
        now,
        timeZone,
        civilDate: practiceDay.civilDate,
        latitude: this.lastLocation?.latitude,
        longitude: this.lastLocation?.longitude,
        calculationMethod: this.el.dataset.calculationMethod || "karachi",
        madhab: this.el.dataset.madhab || "shafi"
      })

      this.pushEvent("browser_context", {
        date: practiceDay.civilDate,
        timezone: timeZone,
        maghrib_at: practiceDay.maghribAt,
        prayer_times: prayerTimes.prayers,
        next_prayer: prayerTimes.nextPrayer,
        ...(this.lastLocation || {})
      })
    }

    this.pushBrowserContext()
    this.bindLocationButton()
    this.timer = window.setInterval(this.pushBrowserContext, 60_000)
    this.visibilityHandler = () => {
      if (document.visibilityState === "visible") this.pushBrowserContext()
    }
    document.addEventListener("visibilitychange", this.visibilityHandler)
  },

  updated() {
    this.bindLocationButton()
    this.syncLocationFromElement()

    const policyFingerprint = this.currentPolicyFingerprint()
    if (policyFingerprint !== this.policyFingerprint) {
      this.policyFingerprint = policyFingerprint
      this.pushBrowserContext()
    }
  },

  destroyed() {
    window.clearInterval(this.timer)
    document.removeEventListener("visibilitychange", this.visibilityHandler)
    this.locationButton?.removeEventListener("click", this.requestBrowserLocation)
  },

  bindLocationButton() {
    const button = this.el.querySelector("[data-browser-location-request]")

    if (button === this.locationButton) return

    this.locationButton?.removeEventListener("click", this.requestBrowserLocation)
    this.locationButton = button
    this.locationButton?.addEventListener("click", this.requestBrowserLocation)
  },

  requestBrowserLocation: function() {
    const button = this.locationButton

    if (!navigator.geolocation) {
      this.setLocationStatus("Location is not available in this browser.")
      return
    }

    if (button) {
      button.disabled = true
      button.setAttribute("aria-busy", "true")
    }
    this.setLocationStatus("Requesting this device's location…")

    navigator.geolocation.getCurrentPosition(
      position => {
        this.lastLocation = {
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracy_m: position.coords.accuracy,
          location_source: "browser"
        }
        this.setLocationStatus("Finding this place…")
        this.reverseBrowserLocation(this.lastLocation).then(locationName => {
          if (locationName) {
            this.lastLocation = withLocationName(this.lastLocation, locationName)
            this.setLocationStatus("Location saved for this browser.")
          } else {
            this.setLocationStatus("Location saved; the place name is unavailable.")
          }
          this.pushBrowserContext()
          this.finishLocationRequest()
        })
      },
      error => {
        const message = error.code === error.PERMISSION_DENIED
          ? "Location permission was not granted."
          : "We could not read this device's location."
        this.setLocationStatus(message)
        this.finishLocationRequest()
      },
      {enableHighAccuracy: false, maximumAge: 300000, timeout: 10000}
    )
  },

  finishLocationRequest() {
    if (this.locationButton) {
      this.locationButton.disabled = false
      this.locationButton.removeAttribute("aria-busy")
    }
  },

  reverseBrowserLocation(location) {
    return new Promise(resolve => {
      let settled = false
      const finish = locationName => {
        if (settled) return
        settled = true
        resolve(locationName)
      }

      this.pushEvent(
        "reverse_location",
        {latitude: location.latitude, longitude: location.longitude},
        reply => finish(reply?.location_name)
      )
      window.setTimeout(() => finish(null), 6000)
    })
  },

  setLocationStatus(message) {
    const status = this.el.querySelector("[data-browser-location-status]")
    if (status) status.textContent = message
  },

  locationFromElement() {
    return locationFromDataset(this.el.dataset)
  },

  locationFingerprint() {
    return datasetLocationFingerprint(this.el.dataset)
  },

  currentPolicyFingerprint() {
    return [
      this.el.dataset.dayReset || "midnight",
      this.el.dataset.calculationMethod || "karachi",
      this.el.dataset.madhab || "shafi"
    ].join("|")
  },

  syncLocationFromElement() {
    const fingerprint = this.locationFingerprint()
    if (fingerprint === this.serverLocationFingerprint) return

    this.serverLocationFingerprint = fingerprint
    this.lastLocation = this.locationFromElement()
    this.pushBrowserContext()
  }
}

const uuidV4 = () => {
  if (window.crypto?.randomUUID) return window.crypto.randomUUID()

  const bytes = window.crypto.getRandomValues(new Uint8Array(16))
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, byte => byte.toString(16).padStart(2, "0")).join("")
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
}

Hooks.CounterButton = {
  mounted() {
    this.lastState = this.el.dataset.countState
    this.ensureCommandId()
    this.keyHandler = event => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault()
        this.el.click()
      }
    }
    this.el.addEventListener("keydown", this.keyHandler)
  },

  updated() {
    if (this.el.dataset.countState !== this.lastState) {
      this.lastState = this.el.dataset.countState
      this.el.removeAttribute("phx-value-command-id")
      this.ensureCommandId()
    }
  },

  destroyed() {
    this.el.removeEventListener("keydown", this.keyHandler)
  },

  ensureCommandId() {
    if (!this.el.getAttribute("phx-value-command-id")) {
      this.el.setAttribute("phx-value-command-id", uuidV4())
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

liveSocket.connect()

window.liveSocket = liveSocket
