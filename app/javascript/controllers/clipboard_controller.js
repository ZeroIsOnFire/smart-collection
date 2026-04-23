import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]
  static values = {
    successContent: String,
    successClass: { type: String, default: "btn-success" },
    defaultClass: { type: String, default: "btn-primary" }
  }

  connect() {
    this.originalContent = this.buttonTarget.innerHTML
  }

  copy(event) {
    event.preventDefault()
    
    // Copy the text to the clipboard
    const text = this.sourceTarget.value
    navigator.clipboard.writeText(text).then(() => {
      this.showSuccess()
    })
  }

  showSuccess() {
    this.buttonTarget.innerHTML = this.successContentValue
    this.buttonTarget.classList.remove(this.defaultClassValue)
    this.buttonTarget.classList.add(this.successClassValue)

    setTimeout(() => {
      this.buttonTarget.innerHTML = this.originalContent
      this.buttonTarget.classList.remove(this.successClassValue)
      this.buttonTarget.classList.add(this.defaultClassValue)
    }, 2000)
  }
}
