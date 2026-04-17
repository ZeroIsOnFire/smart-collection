import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]
  static values = {
    successContent: String
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
    this.buttonTarget.classList.remove("btn-primary")
    this.buttonTarget.classList.add("btn-success")

    setTimeout(() => {
      this.buttonTarget.innerHTML = this.originalContent
      this.buttonTarget.classList.remove("btn-success")
      this.buttonTarget.classList.add("btn-primary")
    }, 2000)
  }
}
