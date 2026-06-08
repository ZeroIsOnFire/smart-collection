import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "icon"]
  static values = {
    showLabel: String,
    hideLabel: String
  }

  toggle() {
    const passwordVisible = this.inputTarget.type === "text"

    this.inputTarget.type = passwordVisible ? "password" : "text"
    this.updateButton(!passwordVisible)
  }

  updateButton(passwordVisible) {
    const label = passwordVisible ? this.hideLabelValue : this.showLabelValue

    this.buttonTarget.setAttribute("aria-label", label)
    this.buttonTarget.setAttribute("title", label)
    this.buttonTarget.setAttribute("aria-pressed", passwordVisible.toString())
    this.iconTarget.classList.toggle("bi-eye", !passwordVisible)
    this.iconTarget.classList.toggle("bi-eye-slash", passwordVisible)
  }
}
