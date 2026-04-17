import { Controller } from "@hotwired/stimulus"

// Stimulus controller for photo upload with drag & drop, preview, and removal.
export default class extends Controller {
  static targets = ["dropzone", "input", "preview", "previewImg", "existingPhoto", "remotePhoto", "removeField", "uploadPrompt"]

  connect() {
    // If there is an existing photo, show it right away
    if (this.hasExistingPhotoTarget && this.existingPhotoTarget.dataset.url) {
      this.showExistingPhoto(this.existingPhotoTarget.dataset.url)
    } else if (this.hasRemotePhotoTarget && this.remotePhotoTarget.dataset.url) {
      this.showExistingPhoto(this.remotePhotoTarget.dataset.url)
    }
  }

  // ------ Click on drop zone ------
  openFilePicker(event) {
    // Don't trigger if clicking the remove button or its children
    if (event.target.closest("[data-action~='photo-upload#removePhoto']")) return
    this.inputTarget.click()
  }

  // ------ File selected via input ------
  fileSelected(event) {
    const file = event.target.files[0]
    if (file) this.showPreview(file)
  }

  // ------ Drag & Drop ------
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
    if (!file) return

    // Transfer the dropped file to the real input so it gets submitted
    const dataTransfer = new DataTransfer()
    dataTransfer.items.add(file)
    this.inputTarget.files = dataTransfer.files

    this.showPreview(file)
  }

  // ------ Remove photo ------
  removePhoto(event) {
    event.stopPropagation()

    // Set hidden field so CarrierWave removes the file
    this.removeFieldTarget.value = "1"

    // Reset file input
    this.inputTarget.value = ""

    // Hide preview, show upload prompt
    this.previewTarget.classList.add("d-none")
    this.uploadPromptTarget.classList.remove("d-none")
  }

  // ------ Helpers ------
  showPreview(file) {
    const reader = new FileReader()
    reader.onload = (e) => {
      this.previewImgTarget.src = e.target.result
      this.previewTarget.classList.remove("d-none")
      this.uploadPromptTarget.classList.add("d-none")
      // Clear remove flag in case it was set before
      this.removeFieldTarget.value = ""
    }
    reader.readAsDataURL(file)
  }

  showExistingPhoto(url) {
    this.previewImgTarget.src = url
    this.previewTarget.classList.remove("d-none")
    this.uploadPromptTarget.classList.add("d-none")
  }
}
