import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    format: String,
    status: String
  }

  connect() {
    if (this.statusValue === 'pending' || this.statusValue === 'processing') {
      this.startTimer()
    }
  }

  disconnect() {
    this.stopTimer()
  }

  startTimer() {
    this.stopTimer()
    // Se estiver travado por mais de 10 segundos, força um refresh do estado
    this.timer = setTimeout(() => {
      this.refresh()
    }, 10000)
  }

  stopTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
    }
  }

  async refresh() {
    const url = `/collection_exports/status?format_type=${this.formatValue}`
    const response = await fetch(url, {
      headers: { "Accept": "text/html" }
    })
    
    if (response.ok) {
      const html = await response.text()
      this.element.outerHTML = html
    }
  }
}
