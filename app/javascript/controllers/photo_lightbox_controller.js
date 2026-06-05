import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  open() {
    if (!this.hasOverlayTarget) return

    this.overlayTarget.classList.remove("d-none")
    document.body.classList.add("photo-lightbox-open")
  }

  close(event) {
    if (event) event.preventDefault()
    if (!this.hasOverlayTarget) return

    this.overlayTarget.classList.add("d-none")
    document.body.classList.remove("photo-lightbox-open")
  }

  closeWithKeyboard(event) {
    if (event.key !== "Escape") return

    this.close(event)
  }

  keepOpen(event) {
    event.stopPropagation()
  }

  disconnect() {
    document.body.classList.remove("photo-lightbox-open")
  }
}
