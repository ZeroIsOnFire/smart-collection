import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, hasMore: Boolean, loading: Boolean }

  connect() {
    this.observer = new IntersectionObserver(this.handleIntersect.bind(this), {
      rootMargin: "200px",
      threshold: 0.1
    })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer.disconnect()
  }

  handleIntersect(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting && this.hasMoreValue && !this.loadingValue) {
        this.load()
      }
    })
  }

  async load() {
    this.loadingValue = true
    this.element.classList.add("is-loading")

    try {
      const response = await fetch(this.urlValue, {
        headers: { "Accept": "text/vnd.turbo-stream.html" }
      })
      const html = await response.text()
      Turbo.renderStreamMessage(html)
    } finally {
      this.loadingValue = false
      this.element.classList.remove("is-loading")
    }
  }
}
