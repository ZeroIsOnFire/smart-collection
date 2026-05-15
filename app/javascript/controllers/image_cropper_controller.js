import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "x", "y", "w", "h", "previewImg"]

  connect() {
    this.modal = new bootstrap.Modal(document.getElementById('cropperModal'))
  }

  open(event) {
    event.preventDefault()
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
      autoCropArea: 1,
      restore: false,
      guides: true,
      center: true,
      highlight: false,
      cropBoxMovable: true,
      cropBoxResizable: true,
      toggleDragModeOnDblclick: false,
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

    // Opcional: Atualizar preview local com o crop
    const canvas = this.cropper.getCroppedCanvas()
    this.previewImgTarget.src = canvas.toDataURL()

    this.modal.hide()
  }

  disconnect() {
    if (this.cropper) {
      this.cropper.destroy()
    }
  }
}
