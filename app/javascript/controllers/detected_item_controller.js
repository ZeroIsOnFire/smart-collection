import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "overlay"]

  connect() {
    this.element.addEventListener("turbo:submit-start", this.startLoading.bind(this))
    this.element.addEventListener("turbo:submit-end", this.stopLoading.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.startLoading.bind(this))
    this.element.removeEventListener("turbo:submit-end", this.stopLoading.bind(this))
  }

  startLoading() {
    this.element.classList.add("is-loading")
  }

  stopLoading() {
    // Note: If the element is replaced by a Turbo Stream, this disconnects automatically.
    // However, if we're doing a simple redirect and the element persists, we clear it.
    this.element.classList.remove("is-loading")
  }

  // Action for non-form buttons (like button_to which is also a form, but just in case)
  showLoading() {
    this.startLoading()
  }
}
