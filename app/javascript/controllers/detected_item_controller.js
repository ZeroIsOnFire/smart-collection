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
    this.element.classList.remove("is-loading")
  }

  showLoading() {
    this.startLoading()
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
}
