import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "spinner", "label"]
  static values = { loadingText: String }

  start() {
    if (!this.hasSubmitTarget) return

    this.submitTarget.disabled = true
    this.submitTarget.setAttribute("aria-busy", "true")

    if (this.hasSpinnerTarget) this.spinnerTarget.classList.remove("d-none")
    if (this.hasLabelTarget && this.loadingTextValue) {
      this.labelTarget.textContent = this.loadingTextValue
    }
  }
}
