import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"

export default class extends Controller {
  static targets = ["video", "canvas", "preview", "previewContainer", "input", "form", "dropzone", "captureBtn", "cameraInterface", "uploadInterface"]

  connect() {
    this.stream = null
  }

  disconnect() {
    this.stopCamera()
  }

  // --- CAMERA LOGIC ---

  async openCamera() {
    try {
      this.uploadInterfaceTarget.classList.add("d-none")
      this.cameraInterfaceTarget.classList.remove("d-none")

      this.stream = await navigator.mediaDevices.getUserMedia({ 
        video: { facingMode: "environment" }, // Prioritiza a câmera traseira em mobile
        audio: false 
      })
      this.videoTarget.srcObject = this.stream
      this.videoTarget.play()
    } catch (err) {
      console.error("Erro ao acessar a câmera:", err)
      alert("Não foi possível acessar a câmera do dispositivo.")
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
      this.stream.getTracks().forEach(track => track.stop())
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
      // REMOVIDO: this.submit() - Agora o usuário confirma manualmente
    }, "image/jpeg", 0.9)
  }

  // --- DRAG & DROP LOGIC ---

  dragOver(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("drag-over")
  }

  dragLeave(event) {
    this.dropzoneTarget.classList.remove("drag-over")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("drag-over")

    const file = event.dataTransfer.files[0]
    if (file && file.type.startsWith("image/")) {
      this.setFile(file)
      // REMOVIDO: this.submit() - Agora o usuário confirma manualmente
    }
  }

  // --- SELECTION LOGIC ---

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
    // Limpa o input e as prévias
    this.inputTarget.value = ""
    this.previewTarget.src = ""
    this.previewContainerTarget.classList.add("d-none")
    this.uploadInterfaceTarget.classList.remove("d-none")
    this.cameraInterfaceTarget.classList.add("d-none")
    this.stopCamera()
  }

  setFile(file) {
    const dataTransfer = new DataTransfer()
    dataTransfer.items.add(file)
    this.inputTarget.files = dataTransfer.files
    
    const reader = new FileReader()
    reader.onload = (e) => {
      this.previewTarget.src = e.target.result
      this.previewContainerTarget.classList.remove("d-none")
      this.uploadInterfaceTarget.classList.add("d-none")
    }
    reader.readAsDataURL(file)
  }

  onStart(event) {
    const btn = document.getElementById("autodetection_submit_btn")
    if (btn) {
      btn.disabled = true
      btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> Iniciando Detecção...'
    }
  }

  onComplete(event) {
    // Se a requisição Turbo finalizou (com sucesso ou erro de validação tratado via Stream)
    // Fechamos o modal e limpamos o estado para não travar a tela
    const modalElement = document.getElementById('autodetectModal')
    if (modalElement) {
      const modal = bootstrap.Modal.getInstance(modalElement) || bootstrap.Modal.getOrCreateInstance(modalElement)
      if (modal) {
        modal.hide()
      }
    }
    
    // Restauramos o botão caso o usuário abra o modal novamente no futuro
    const btn = document.getElementById("autodetection_submit_btn")
    if (btn) {
      btn.disabled = false
      btn.innerHTML = '<i class="bi bi-magic"></i> <span id="autodetection_submit_text">Confirmar</span>'
    }
    
    this.reset()
  }
}
