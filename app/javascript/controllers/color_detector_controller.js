import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "select", "preview"]
  static values = { colors: Object, detectUrl: String }

  connect() {
    this.updatePreview()
  }

  async detect(event) {
    const file = event.target.files[0]
    if (!file || !this.hasDetectUrlValue) return

    const formData = new FormData()
    formData.append("photo", file)

    try {
      const response = await fetch(this.detectUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "application/json"
        },
        body: formData
      })

      if (response.ok) {
        const data = await response.json()
        if (data.color && this.hasSelectTarget) {
          this.selectTarget.value = data.color
          this.updatePreview()
        }
      }
    } catch (error) {
      console.error("Erro ao detectar cor:", error)
    }
  }

  updatePreview() {
    if (!this.hasSelectTarget || !this.hasPreviewTarget) return
    
    const selectedColorName = this.selectTarget.value
    const hex = this.colorsValue[selectedColorName] || 'transparent'
    
    this.previewTarget.style.backgroundColor = hex
    if (hex === 'transparent' || hex === '#FFFFFF') {
      this.previewTarget.style.border = '1px solid #dee2e6'
    } else {
      this.previewTarget.style.border = 'none'
    }
  }
}
