import { Controller } from "@hotwired/stimulus"
import { t } from "../i18n"

export default class extends Controller {
  static values = { interval: Number }

  connect() {
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    const interval = this.intervalValue || 5000
    this.timer = setInterval(() => {
      if (this.element.tagName === "TURBO-FRAME") {
        const url = new URL(window.location.href)
        url.searchParams.set("t", Date.now())

        fetch(url.toString(), {
          headers: {
            "Accept": "text/html, application/xhtml+xml",
            "Turbo-Frame": this.element.id
          }
        })
          .then((response) => response.text())
          .then((html) => {
            const parser = new DOMParser()
            const doc = parser.parseFromString(html, "text/html")
            const newFrame = doc.getElementById(this.element.id)
            if (newFrame) {
              this.element.innerHTML = newFrame.innerHTML
            }
          })
          .catch((err) => console.error(t("javascript.poll.error_console"), err))
      } else {
        window.location.reload()
      }
    }, interval)
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }
}
