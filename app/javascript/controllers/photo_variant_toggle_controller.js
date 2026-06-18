import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "lightboxImage", "buttonLabel"]
  static values = {
    aiUrl: String,
    originalUrl: String,
    originalLabel: String,
    aiLabel: String
  }

  connect() {
    this.showingOriginal = false
  }

  toggle(event) {
    event.preventDefault()
    this.showingOriginal = !this.showingOriginal

    const url = this.showingOriginal ? this.originalUrlValue : this.aiUrlValue
    this.imageTargets.forEach((image) => {
      image.src = url
    })
    this.lightboxImageTargets.forEach((image) => {
      image.src = url
    })

    if (this.hasButtonLabelTarget) {
      this.buttonLabelTarget.textContent = this.showingOriginal ? this.aiLabelValue : this.originalLabelValue
    }
  }
}
