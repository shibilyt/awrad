import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

const Hooks = {}

Hooks.BrowserClock = {
  mounted() {
    this.pushBrowserContext = () => {
      const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC"
      const parts = new Intl.DateTimeFormat("en-CA", {
        year: "numeric",
        month: "2-digit",
        day: "2-digit"
      }).formatToParts(new Date())
      const values = Object.fromEntries(parts.map(({type, value}) => [type, value]))
      const date = `${values.year}-${values.month}-${values.day}`

      this.pushEvent("browser_context", {date, timezone: timeZone})
    }

    this.pushBrowserContext()
    this.timer = window.setInterval(this.pushBrowserContext, 60_000)
    this.visibilityHandler = () => {
      if (document.visibilityState === "visible") this.pushBrowserContext()
    }
    document.addEventListener("visibilitychange", this.visibilityHandler)
  },

  destroyed() {
    window.clearInterval(this.timer)
    document.removeEventListener("visibilitychange", this.visibilityHandler)
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
