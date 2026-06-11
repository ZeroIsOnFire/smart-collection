import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]
  static values = {
    loadingLabel: String
  }

  connect() {
    this.startLoadingHandler = this.startLoading.bind(this)
    this.stopLoadingHandler = this.stopLoading.bind(this)

    this.element.addEventListener("turbo:submit-start", this.startLoadingHandler)
    this.element.addEventListener("turbo:submit-end", this.stopLoadingHandler)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.startLoadingHandler)
    this.element.removeEventListener("turbo:submit-end", this.stopLoadingHandler)
  }

  startLoading() {
    this.element.classList.add("is-loading")
    this.disableControls()
  }

  stopLoading() {
    this.element.classList.remove("is-loading")
    this.restoreControls()
  }

  openAdjustmentModal(event) {
    event.preventDefault()

    // O frame id é detected_item_ID
    const frameId = this.element.id
    const itemId = frameId.replace("detected_item_", "")
    const modalId = `adjustmentModal_${itemId}`
    const modalElement = document.getElementById(modalId)

    if (modalElement && typeof bootstrap !== 'undefined') {
      const modal = new bootstrap.Modal(modalElement)
      modal.show()
    }
  }

  disableControls() {
    this.controls.forEach((control) => {
      control.dataset.detectedItemOriginalDisabled = control.disabled.toString()
      control.disabled = true
    })

    if (this.hasSubmitTarget) {
      this.submitTarget.dataset.detectedItemOriginalHtml ||= this.submitTarget.innerHTML
      this.submitTarget.innerHTML = this.submitTarget.dataset.loadingHtml || this.loadingLabelValue
    }
  }

  restoreControls() {
    this.controls.forEach((control) => {
      control.disabled = control.dataset.detectedItemOriginalDisabled === "true"
      delete control.dataset.detectedItemOriginalDisabled
    })

    if (this.hasSubmitTarget && this.submitTarget.dataset.detectedItemOriginalHtml) {
      this.submitTarget.innerHTML = this.submitTarget.dataset.detectedItemOriginalHtml
      delete this.submitTarget.dataset.detectedItemOriginalHtml
    }
  }

  get controls() {
    return Array.from(this.element.querySelectorAll("button, input, select, textarea"))
  }
}
