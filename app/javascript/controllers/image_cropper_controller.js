import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "x", "y", "w", "h", "previewImg"]

  connect() {
    this.modal = new bootstrap.Modal(document.getElementById('cropperModal'))
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()
    const src = this.previewImgTarget.src
    if (!src || src.includes('data:image')) {
      // Se for base64 (upload novo), precisamos carregar no cropper
      this.imageTarget.src = src
    } else {
      this.imageTarget.src = src
    }
    
    this.modal.show()
  }

  initCropper() {
    if (this.cropper) {
      this.cropper.destroy()
    }

    this.cropper = new Cropper(this.imageTarget, {
      viewMode: 1,
      dragMode: 'move',
      autoCropArea: 1, // Preenche a imagem toda inicialmente
      restore: false,
      guides: true,
      center: true,
      highlight: false,
      cropBoxMovable: true,
      cropBoxResizable: true,
      toggleDragModeOnDblclick: false,
      responsive: true,
      checkOrientation: true,
      background: false
    })
  }

  save() {
    const data = this.cropper.getData()
    const imageData = this.cropper.getImageData()

    // Salva valores normalizados para o backend processar na imagem original
    this.xTarget.value = data.x / imageData.naturalWidth
    this.yTarget.value = data.y / imageData.naturalHeight
    this.wTarget.value = data.width / imageData.naturalWidth
    this.hTarget.value = data.height / imageData.naturalHeight

    // Atualizar preview local com o crop
    const canvas = this.cropper.getCroppedCanvas()
    this.previewImgTarget.src = canvas.toDataURL()

    // Autodetecção após o recorte
    this.runClassification(canvas)

    this.modal.hide()
  }

  async runClassification(canvas) {
    const detectUrl = this.element.dataset.imageCropperDetectUrlValue
    if (!detectUrl) return

    canvas.toBlob(async (blob) => {
      const formData = new FormData()
      formData.append("photo", blob)

      try {
        const response = await fetch(detectUrl, {
          method: "POST",
          headers: {
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
            "Accept": "application/json"
          },
          body: formData
        })

        if (response.ok) {
          const result = await response.json()
          this.updateFormFields(result)
        }
      } catch (error) {
        console.error("Erro na classificação após recorte:", error)
      }
    })
  }

  updateFormFields(result) {
    // Busca os campos de nome e fabricante se estiverem vazios
    const nameField = document.querySelector('input[name="car[name]"]')
    const manufacturerField = document.querySelector('input[name="car[manufacturer]"]')
    const colorSelect = document.querySelector('select[name="car[color]"]')

    if (nameField && !nameField.value && result.label) {
      nameField.value = result.label.charAt(0).toUpperCase() + result.label.slice(1)
    }

    if (colorSelect && result.color) {
      colorSelect.value = result.color
      // Notifica o controlador de cor para atualizar o preview (bolinha)
      colorSelect.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }

  disconnect() {
    if (this.cropper) {
      this.cropper.destroy()
    }
  }
}
