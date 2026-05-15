import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["image"]
  static values = {
    initialX: Number,
    initialY: Number,
    initialWidth: Number,
    initialHeight: Number,
    updateUrl: String,
    loadingText: String,
    saveErrorText: String,
    unexpectedErrorText: String
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
    } else {
      setTimeout(() => {
        this.initCropper()
      }, 300)
    }
  }

  disconnect() {
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
      console.error("Cropper.js not found!")
      return
    }

    const image = this.imageTarget
    this.cropper = new Cropper(image, {
      viewMode: 1,
      dragMode: "move",
      autoCropArea: 1,
      restore: false,
      guides: true,
      center: true,
      highlight: false,
      cropBoxMovable: true,
      cropBoxResizable: true,
      toggleDragModeOnDblclick: false,
      responsive: true,
      background: false,
      ready: () => {
        const imageData = this.cropper.getImageData()
        const naturalWidth = imageData.naturalWidth
        const naturalHeight = imageData.naturalHeight

        const x = this.initialXValue * naturalWidth
        const y = this.initialYValue * naturalHeight
        const width = this.initialWidthValue * naturalWidth
        const height = this.initialHeightValue * naturalHeight

        this.cropper.setData({
          x: x,
          y: y,
          width: width,
          height: height
        })

        image.style.opacity = '1'
      }
    })
  }

  async save(event) {
    const btn = event.currentTarget
    const originalText = btn.innerHTML
    const loadingText = this.loadingTextValue || "Saving..."
    
    btn.innerHTML = `<span class="spinner-border spinner-border-sm me-1"></span> ${loadingText}`
    btn.disabled = true

    try {
      const data = this.cropper.getData()
      const imageData = this.cropper.getImageData()

      const normalized = {
        x: data.x / imageData.naturalWidth,
        y: data.y / imageData.naturalHeight,
        width: data.width / imageData.naturalWidth,
        height: data.height / imageData.naturalHeight
      }

      // Coletar dados do formulário atual para não perdê-los no reload
      const frameId = this.element.closest("turbo-frame").id
      const itemId = frameId.replace("detected_item_", "")
      const brand = document.getElementById(`brand_${itemId}`)?.value
      const manufacturer = document.getElementById(`manufacturer_${itemId}`)?.value
      const name = document.getElementById(`name_${itemId}`)?.value
      const color = document.getElementById(`color_${itemId}`)?.value
      const year = document.getElementById(`year_${itemId}`)?.value
      const size = document.getElementById(`size_${itemId}`)?.value

      const payload = {
        ...normalized,
        brand,
        manufacturer,
        name,
        color,
        year,
        size
      }

      const response = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify(payload)
      })

      if (response.ok) {
        const modalElement = this.element.closest(".modal")
        if (typeof bootstrap !== "undefined" && modalElement) {
          const modal = bootstrap.Modal.getInstance(modalElement)
          if (modal) modal.hide()
        }

        document.body.classList.remove("modal-open")
        document.body.style.overflow = ""
        document.body.style.paddingRight = ""
        document.querySelectorAll(".modal-backdrop").forEach((element) => element.remove())

        const html = await response.text()
        Turbo.renderStreamMessage(html)
      } else {
        const errorMsg = this.saveErrorTextValue || "Error saving selection"
        alert(`${errorMsg} (${response.status})`)
      }
    } catch (error) {
      console.error("Error saving adjustment:", error)
      const unexpectedMsg = this.unexpectedErrorTextValue || "An unexpected error occurred"
      alert(`${unexpectedMsg}: ${error.message}`)
    } finally {
      if (document.body.contains(btn)) {
        btn.innerHTML = originalText
        btn.disabled = false
      }
    }
  }
}
