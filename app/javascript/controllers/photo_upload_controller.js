import { Controller } from "@hotwired/stimulus"

// Stimulus controller for photo upload with drag & drop, preview, and removal.
export default class extends Controller {
  static targets = [
    "dropzone",
    "input",
    "preview",
    "previewImg",
    "existingPhoto",
    "remotePhoto",
    "removeField",
    "uploadPrompt",
    "upscalerToggle",
    "upscalerCheckbox",
    "upscalerExistingLabel",
    "upscalerNewLabel",
    "variantComparison",
    "originalVariantCard",
    "aiVariantCard",
    "originalVariantStatus",
    "aiVariantStatus"
  ]
  static values = {
    minimumSide: Number
  }

  connect() {
    // If there is an existing photo, show it right away
    if (this.hasExistingPhotoTarget && this.existingPhotoTarget.dataset.url) {
      this.showExistingPhoto(this.existingPhotoTarget.dataset.url)
    } else if (this.hasRemotePhotoTarget && this.remotePhotoTarget.dataset.url) {
      this.showExistingPhoto(this.remotePhotoTarget.dataset.url)
    } else {
      this.hideUpscalerToggle()
    }
  }

  // ------ Click on drop zone ------
  openFilePicker(event) {
    // Don't trigger if clicking the remove button or crop button or its children
    if (event.target.closest("[data-action~='photo-upload#removePhoto']")) return
    if (event.target.closest("[data-action~='image-cropper#open']")) return
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

  dragLeave() {
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
    this.hideUpscalerToggle()
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
      this.updateNewPhotoUpscalerVisibility(e.target.result)
    }
    reader.readAsDataURL(file)
  }

  updateNewPhotoUpscalerVisibility(url) {
    const image = new Image()
    image.onload = () => {
      const minimumSide = this.minimumSideValue || 360
      if (Math.min(image.naturalWidth, image.naturalHeight) < minimumSide) {
        this.showNewPhotoUpscalerMessage()
        this.showUpscalerToggle()
      } else {
        this.hideUpscalerToggle()
      }
    }
    image.onerror = () => {
      this.hideUpscalerToggle()
    }
    image.src = url
  }

  showExistingPhoto(url) {
    this.previewImgTarget.src = url
    this.previewTarget.classList.remove("d-none")
    this.uploadPromptTarget.classList.add("d-none")
    if (this.hasUpscalerToggleTarget && this.upscalerToggleTarget.dataset.persistVisible === "true") {
      this.showUpscalerToggle()
      this.showExistingPhotoUpscalerMessage()
    } else {
      this.hideUpscalerToggle()
    }
  }

  showNewPhotoUpscalerMessage() {
    if (this.hasVariantComparisonTarget) this.variantComparisonTarget.classList.add("d-none")
    if (this.hasUpscalerExistingLabelTarget) this.upscalerExistingLabelTarget.classList.add("d-none")
    if (this.hasUpscalerNewLabelTarget) this.upscalerNewLabelTarget.classList.remove("d-none")
  }

  showExistingPhotoUpscalerMessage() {
    if (this.hasVariantComparisonTarget) this.variantComparisonTarget.classList.remove("d-none")
    if (this.hasUpscalerExistingLabelTarget) this.upscalerExistingLabelTarget.classList.remove("d-none")
    if (this.hasUpscalerNewLabelTarget) this.upscalerNewLabelTarget.classList.add("d-none")
    this.updateVariantSelection()
  }

  updateVariantSelection() {
    if (!this.hasUpscalerCheckboxTarget) return

    const originalSelected = this.upscalerCheckboxTarget.checked
    if (this.hasOriginalVariantCardTarget && this.hasOriginalVariantStatusTarget) {
      this.setVariantState(this.originalVariantCardTarget, this.originalVariantStatusTarget, originalSelected)
    }
    if (this.hasAiVariantCardTarget && this.hasAiVariantStatusTarget) {
      this.setVariantState(this.aiVariantCardTarget, this.aiVariantStatusTarget, !originalSelected)
    }
  }

  setVariantState(card, status, selected) {
    if (!card || !status) return

    card.classList.toggle("is-selected", selected)
    status.classList.toggle("is-check", selected)
    status.classList.toggle("is-cross", !selected)
    const icon = status.querySelector("i")
    if (!icon) return

    icon.classList.toggle("bi-check-lg", selected)
    icon.classList.toggle("bi-x-lg", !selected)
  }

  showUpscalerToggle() {
    if (this.hasUpscalerToggleTarget) this.upscalerToggleTarget.classList.remove("d-none")
  }

  hideUpscalerToggle() {
    if (this.hasUpscalerToggleTarget) this.upscalerToggleTarget.classList.add("d-none")
  }
}
