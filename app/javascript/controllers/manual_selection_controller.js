import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["image"]
  static values = {
    createUrl: String
  }

  connect() {
    this.modalElement = this.element.closest('.modal')
    
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
      this.modalElement.addEventListener('shown.bs.modal', this.handleModalShown)
      this.modalElement.addEventListener('hidden.bs.modal', this.handleModalHidden)
    }
  }

  disconnect() {
    if (this.modalElement) {
      this.modalElement.removeEventListener('shown.bs.modal', this.handleModalShown)
      this.modalElement.removeEventListener('hidden.bs.modal', this.handleModalHidden)
    }
    if (this.cropper) {
      this.cropper.destroy()
      this.cropper = null
    }
  }

  initCropper() {
    if (typeof Cropper === 'undefined') {
      console.error('Cropper.js não encontrado!')
      return
    }

    const image = this.imageTarget
    this.cropper = new Cropper(image, {
      viewMode: 1,
      dragMode: 'crop',
      autoCropArea: 0.2, // Começa com uma seleção pequena no centro
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
    const originalText = btn.innerHTML
    btn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Criando...'
    btn.disabled = true

    try {
      const data = this.cropper.getData()
      const imageData = this.cropper.getImageData()
      
      // Normaliza as coordenadas para o backend (0 a 1)
      const normalized = {
        x: data.x / imageData.naturalWidth,
        y: data.y / imageData.naturalHeight,
        width: data.width / imageData.naturalWidth,
        height: data.height / imageData.naturalHeight
      }

      const response = await fetch(this.createUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'text/vnd.turbo-stream.html'
        },
        body: JSON.stringify(normalized)
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        
        // Resetamos a área de seleção mas mantemos o modal aberto
        this.cropper.reset()
        
      } else {
        alert('Erro ao criar o item. O servidor retornou ' + response.status)
      }
    } catch (error) {
      console.error('Erro na criação manual:', error)
      alert('Ocorreu um erro inesperado: ' + error.message)
    } finally {
      if (document.body.contains(btn)) {
        btn.innerHTML = originalText
        btn.disabled = false
      }
    }
  }
}
