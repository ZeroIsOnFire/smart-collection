import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["image"]
  static values = {
    createUrl: String
  }

  connect() {
    this.modalElement = this.element.closest(".modal")

    if (this.modalElement) {
      this.handleModalShown = () => {
        if (!this.cropper) {
          this.initCropper()
        }
      }

      this.handleModalHidden = () => {
        if (this.cropper) {
          this.cropper.destroy()
          this.cropper = null
        }
      }

      this.modalElement.addEventListener("shown.bs.modal", this.handleModalShown)
      this.modalElement.addEventListener("hidden.bs.modal", this.handleModalHidden)
    }
  }

  disconnect() {
    this.clearSuccessTimer()

    if (this.modalElement) {
      this.modalElement.removeEventListener("shown.bs.modal", this.handleModalShown)
      this.modalElement.removeEventListener("hidden.bs.modal", this.handleModalHidden)
    }

    if (this.cropper) {
      this.cropper.destroy()
      this.cropper = null
    }
  }

  initCropper() {
    if (typeof Cropper === "undefined") {
      console.error("Cropper.js nao encontrado!")
      return
    }

    const image = this.imageTarget
    this.cropper = new Cropper(image, {
      viewMode: 1,
      dragMode: "crop",
      autoCropArea: 0.2,
      restore: false,
      guides: true,
      center: true,
      highlight: false,
      cropBoxMovable: true,
      cropBoxResizable: true,
      toggleDragModeOnDblclick: false
    })
  }

  async save(event) {
    const btn = event.currentTarget
    this.setLoadingState(btn)

    try {
      const data = this.cropper.getData()
      const imageData = this.cropper.getImageData()

      const normalized = {
        x: data.x / imageData.naturalWidth,
        y: data.y / imageData.naturalHeight,
        width: data.width / imageData.naturalWidth,
        height: data.height / imageData.naturalHeight
      }

      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify(normalized)
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        this.cropper.reset()
        this.setSuccessState(btn)
      } else {
        alert("Erro ao criar o item. O servidor retornou " + response.status)
        this.resetButton(btn)
      }
    } catch (error) {
      console.error("Erro na criacao manual:", error)
      alert("Ocorreu um erro inesperado: " + error.message)
      this.resetButton(btn)
    }
  }

  setLoadingState(btn) {
    this.clearSuccessTimer()
    this.storeOriginalState(btn)
    btn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Criando...'
    btn.disabled = true
  }

  setSuccessState(btn) {
    if (!document.body.contains(btn)) return

    this.storeOriginalState(btn)
    btn.classList.remove("btn-premium")
    btn.classList.add("btn-success")
    btn.innerHTML = '<i class="bi bi-check-circle-fill me-1"></i> Adicionado!'
    btn.disabled = true

    this.successTimer = setTimeout(() => {
      this.resetButton(btn)
    }, 1800)
  }

  resetButton(btn) {
    if (!btn || !document.body.contains(btn)) return

    btn.innerHTML = btn.dataset.originalHtml || btn.innerHTML
    btn.classList.remove("btn-success")
    btn.classList.add("btn-premium")
    btn.disabled = false
  }

  storeOriginalState(btn) {
    if (!btn.dataset.originalHtml) {
      btn.dataset.originalHtml = btn.innerHTML
    }
  }

  clearSuccessTimer() {
    if (this.successTimer) {
      clearTimeout(this.successTimer)
      this.successTimer = null
    }
  }
}
