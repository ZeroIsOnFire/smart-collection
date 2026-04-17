import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["image"]
  static values = {
    initialX: Number,
    initialY: Number,
    initialWidth: Number,
    initialHeight: Number,
    updateUrl: String
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
    } else {
      setTimeout(() => {
        this.initCropper()
      }, 300)
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
      console.error('Cropper.js não encontrado! Verifique se os CDNs no layout estão corretos.')
      return
    }

    const image = this.imageTarget
    this.cropper = new Cropper(image, {
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
      ready: () => {
        const imageData = this.cropper.getImageData()
        const naturalWidth = imageData.naturalWidth
        const naturalHeight = imageData.naturalHeight

        // Converte os valores iniciais (que são frações de 0 a 1) para pixels reais da imagem original
        const x = this.initialXValue * naturalWidth
        const y = this.initialYValue * naturalHeight
        const width = this.initialWidthValue * naturalWidth
        const height = this.initialHeightValue * naturalHeight

        // Posiciona a caixa de seleção exatamente onde o Vision API detectou inicialmente
        this.cropper.setData({
          x: x,
          y: y,
          width: width,
          height: height
        })
      }
    })
  }

  async save(event) {
    const btn = event.currentTarget
    const originalText = btn.innerHTML
    btn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Salvando...'
    btn.disabled = true

    try {
      const data = this.cropper.getData()
      const imageData = this.cropper.getImageData()
      
      // Normaliza as coordenadas novamente para o backend (0 a 1)
      const normalized = {
        x: data.x / imageData.naturalWidth,
        y: data.y / imageData.naturalHeight,
        width: data.width / imageData.naturalWidth,
        height: data.height / imageData.naturalHeight
      }

      const response = await fetch(this.updateUrlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'text/vnd.turbo-stream.html'
        },
        body: JSON.stringify(normalized)
      })

      if (response.ok) {
        // Fechar modal MANUALMENTE e limpar o DOM do Bootstrap antes de substituir
        const modalElement = this.element.closest('.modal')
        if (typeof bootstrap !== 'undefined' && modalElement) {
          const modal = bootstrap.Modal.getInstance(modalElement)
          if (modal) modal.hide()
        }
        
        // Remove a camada escura que frequentemente fica travada no Turbo Streams
        document.body.classList.remove('modal-open');
        document.body.style.overflow = '';
        document.body.style.paddingRight = '';
        document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());

        const html = await response.text()
        Turbo.renderStreamMessage(html)
        
      } else {
        alert('Erro ao salvar o ajuste. O servidor retornou ' + response.status)
      }
    } catch (error) {
      console.error('Erro no ajuste de seleção:', error)
      alert('Ocorreu um erro inesperado ao salvar o ajuste: ' + error.message)
    } finally {
      if (document.body.contains(btn)) {
        btn.innerHTML = originalText
        btn.disabled = false
      }
    }
  }
}
