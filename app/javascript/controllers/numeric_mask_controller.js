import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.inputMode = "numeric"
    this.element.pattern = "[0-9]*"
  }

  sanitize() {
    const originalValue = this.element.value
    const sanitizedValue = originalValue.replace(/\D/g, "")

    if (sanitizedValue === originalValue) return

    const cursorPosition = this.element.selectionStart
    const removedBeforeCursor = originalValue.slice(0, cursorPosition).replace(/\d/g, "").length

    this.element.value = sanitizedValue
    this.element.setSelectionRange(
      Math.max(cursorPosition - removedBeforeCursor, 0),
      Math.max(cursorPosition - removedBeforeCursor, 0)
    )
  }
}
