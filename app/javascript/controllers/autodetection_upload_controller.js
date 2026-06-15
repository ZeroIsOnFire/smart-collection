import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"
import { t } from "../i18n"

export default class extends Controller {
  static targets = [
    "video",
    "canvas",
    "preview",
    "previewContainer",
    "input",
    "form",
    "dropzone",
    "captureBtn",
    "cameraInterface",
    "uploadInterface",
    "upscalerControls",
    "skipUpscaler"
  ]
  static values = {
    minimumSide: Number
  }

  connect() {
    this.stream = null
  }

  disconnect() {
    this.stopCamera()
  }

  async openCamera() {
    try {
      this.uploadInterfaceTarget.classList.add("d-none")
      this.cameraInterfaceTarget.classList.remove("d-none")

      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment" },
        audio: false
      })
      this.videoTarget.srcObject = this.stream
      this.videoTarget.play()
    } catch (err) {
      console.error(t("javascript.autodetection_upload.errors.camera_console"), err)
      alert(t("javascript.autodetection_upload.errors.camera_access"))
      this.closeCamera()
    }
  }

  closeCamera() {
    this.stopCamera()
    this.cameraInterfaceTarget.classList.add("d-none")
    this.uploadInterfaceTarget.classList.remove("d-none")
  }

  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop())
      this.stream = null
    }
  }

  capture() {
    const context = this.canvasTarget.getContext("2d")
    this.canvasTarget.width = this.videoTarget.videoWidth
    this.canvasTarget.height = this.videoTarget.videoHeight
    context.drawImage(this.videoTarget, 0, 0, this.canvasTarget.width, this.canvasTarget.height)

    this.canvasTarget.toBlob((blob) => {
      const file = new File([blob], "captured_photo.jpg", { type: "image/jpeg" })
      this.setFile(file)
      this.stopCamera()
      this.cameraInterfaceTarget.classList.add("d-none")
    }, "image/jpeg", 0.9)
  }

  dragOver(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("drag-over")
  }

  dragLeave() {
    this.dropzoneTarget.classList.remove("drag-over")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("drag-over")

    const file = event.dataTransfer.files[0]
    if (file && file.type.startsWith("image/")) {
      this.setFile(file)
    }
  }

  selectFile() {
    this.inputTarget.click()
  }

  fileSelected(event) {
    const file = event.target.files[0]
    if (file) {
      this.setFile(file)
    }
  }

  reset() {
    this.inputTarget.value = ""
    this.previewTarget.src = ""
    this.previewContainerTarget.classList.add("d-none")
    this.uploadInterfaceTarget.classList.remove("d-none")
    this.cameraInterfaceTarget.classList.add("d-none")
    this.hideUpscalerControls()
    this.stopCamera()
  }

  setFile(file) {
    const dataTransfer = new DataTransfer()
    dataTransfer.items.add(file)
    this.inputTarget.files = dataTransfer.files

    const reader = new FileReader()
    reader.onload = (event) => {
      this.previewTarget.src = event.target.result
      this.previewContainerTarget.classList.remove("d-none")
      this.uploadInterfaceTarget.classList.add("d-none")
      this.updateUpscalerControls(event.target.result)
    }
    reader.readAsDataURL(file)
  }

  updateUpscalerControls(url) {
    const image = new Image()
    image.onload = () => {
      const minimumSide = this.minimumSideValue || 800

      if (Math.min(image.naturalWidth || 0, image.naturalHeight || 0) < minimumSide) {
        this.showUpscalerControls()
      } else {
        this.hideUpscalerControls()
      }
    }
    image.onerror = () => {
      this.hideUpscalerControls()
    }
    image.src = url
  }

  showUpscalerControls() {
    if (this.hasUpscalerControlsTarget) this.upscalerControlsTarget.classList.remove("d-none")
  }

  hideUpscalerControls() {
    if (this.hasUpscalerControlsTarget) this.upscalerControlsTarget.classList.add("d-none")
    if (this.hasSkipUpscalerTarget) this.skipUpscalerTarget.checked = false
  }

  onStart() {
    const btn = document.getElementById("autodetection_submit_btn")
    if (btn) {
      btn.dataset.originalHtml ||= btn.innerHTML
      btn.disabled = true
      btn.innerHTML = `<span class="spinner-border spinner-border-sm"></span> ${t("javascript.autodetection_upload.loading")}`
    }
  }

  onComplete() {
    const modalElement = document.getElementById("autodetectModal")
    if (modalElement) {
      const modal = bootstrap.Modal.getInstance(modalElement) || bootstrap.Modal.getOrCreateInstance(modalElement)
      if (modal) modal.hide()
    }

    const btn = document.getElementById("autodetection_submit_btn")
    if (btn) {
      btn.disabled = false
      btn.innerHTML = btn.dataset.originalHtml || btn.innerHTML
    }

    this.reset()
  }
}
