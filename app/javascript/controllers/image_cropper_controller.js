import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "x", "y", "w", "h", "previewImg"]

  connect() {
    this.modalElement = document.getElementById('cropperModal')
    if (this.modalElement) {
      this.modal = new bootstrap.Modal(this.modalElement)
      
      // Inicializar cropper apenas quando o modal terminar de abrir
      // para garantir que as dimensões do container estejam corretas
      this.modalElement.addEventListener('shown.bs.modal', () => {
        this.initCropper()
      })

      // Destruir ao fechar para evitar vazamento de memória
      this.modalElement.addEventListener('hidden.bs.modal', (event) => {
        if (event.target !== this.modalElement) return

        if (this.cropper) {
          this.cropper.destroy()
          this.cropper = null
        }

        if (document.getElementById("turboModal")?.classList.contains("show")) {
          document.body.classList.add("modal-open")
        }
      })
    }
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()
    const src = this.previewImgTarget.dataset.cropSourceUrl || this.previewImgTarget.src
    if (src) {
      this.imageTarget.style.opacity = '0'
      this.imageTarget.src = src
      this.modal.show()
    }
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
      responsive: true,
      checkOrientation: true,
      background: false,
      ready: () => {
        this.applyStoredCrop()
        this.imageTarget.style.opacity = '1'
      }
    })
  }

  applyStoredCrop() {
    const crop = this.storedCrop()
    if (!crop) return

    const imageData = this.cropper.getImageData()
    this.cropper.setData({
      x: crop.x * imageData.naturalWidth,
      y: crop.y * imageData.naturalHeight,
      width: crop.w * imageData.naturalWidth,
      height: crop.h * imageData.naturalHeight
    })
  }

  storedCrop() {
    const crop = {
      x: Number.parseFloat(this.xTarget.value),
      y: Number.parseFloat(this.yTarget.value),
      w: Number.parseFloat(this.wTarget.value),
      h: Number.parseFloat(this.hTarget.value)
    }

    if ([crop.x, crop.y, crop.w, crop.h].some((value) => Number.isNaN(value))) return null
    if (crop.w <= 0 || crop.h <= 0) return null

    return {
      x: Math.max(0, crop.x),
      y: Math.max(0, crop.y),
      w: Math.min(1, crop.w),
      h: Math.min(1, crop.h)
    }
  }

  save() {
    if (!this.cropper) return

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
    this.element.dispatchEvent(new CustomEvent("photo-upload:crop-change", {
      bubbles: true,
      detail: {
        width: data.width,
        height: data.height
      }
    }))

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
    const colorSelect = document.querySelector('select[name="car[color]"]')

    // Removido auto-preenchimento de nome pois 'car' ou 'truck' não é útil como nome de colecionável
    // e o usuário não solicitou este comportamento neste formulário.

    if (colorSelect && result.color) {
      colorSelect.value = result.color
      colorSelect.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }

  disconnect() {
    if (this.cropper) {
      this.cropper.destroy()
    }
  }
}
