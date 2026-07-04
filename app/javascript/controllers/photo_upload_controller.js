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
      this.showRemotePhoto(this.remotePhotoTarget.dataset.url)
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
    this.previewImgTarget.removeAttribute("data-crop-source-url")
    this.clearCropFields()
    this.disablePersistedVariantComparison()

    // Hide preview, show upload prompt
    this.previewTarget.classList.add("d-none")
    this.uploadPromptTarget.classList.remove("d-none")
    this.hideUpscalerToggle()
  }

  // ------ Helpers ------
  showPreview(file) {
    const reader = new FileReader()
    reader.onload = (e) => {
      this.disablePersistedVariantComparison()
      this.clearCropFields()
      this.previewImgTarget.src = e.target.result
      this.previewImgTarget.dataset.cropSourceUrl = e.target.result
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
      this.updateUpscalerVisibilityForSize(image.naturalWidth, image.naturalHeight)
    }
    image.onerror = () => {
      this.hideUpscalerToggle()
    }
    image.src = url
  }

  cropChanged(event) {
    const { width, height } = event.detail || {}
    this.updateUpscalerVisibilityForSize(width, height)
  }

  updateUpscalerVisibilityForSize(width, height) {
    if (this.persistVariantComparisonVisible) {
      this.showExistingPhotoUpscalerMessage()
      this.showUpscalerToggle()
      return
    }

    const minimumSide = this.minimumSideValue || 360
    if (Math.min(width || 0, height || 0) < minimumSide) {
      this.showNewPhotoUpscalerMessage()
      this.showUpscalerToggle()
    } else {
      this.hideUpscalerToggle()
    }
  }

  showExistingPhoto(url) {
    this.previewImgTarget.dataset.cropSourceUrl = url
    this.previewImgTarget.src = url
    this.renderStoredCropPreview(url)
    this.previewTarget.classList.remove("d-none")
    this.uploadPromptTarget.classList.add("d-none")
    if (this.persistVariantComparisonVisible) {
      this.showUpscalerToggle()
      this.showExistingPhotoUpscalerMessage()
    } else {
      this.hideUpscalerToggle()
    }
  }

  showRemotePhoto(url) {
    this.previewImgTarget.dataset.cropSourceUrl = url
    this.previewImgTarget.src = url
    this.renderStoredCropPreview(url)
    this.previewTarget.classList.remove("d-none")
    this.uploadPromptTarget.classList.add("d-none")
    this.showNewPhotoUpscalerMessage()
    this.showUpscalerToggle()
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

  selectOriginalVariant() {
    if (!this.hasUpscalerCheckboxTarget) return

    this.upscalerCheckboxTarget.checked = true
    this.upscalerCheckboxTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.updateVariantSelection()
  }

  selectAiVariant() {
    if (!this.hasUpscalerCheckboxTarget) return

    this.upscalerCheckboxTarget.checked = false
    this.upscalerCheckboxTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.updateVariantSelection()
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

  clearCropFields() {
    this.element.querySelectorAll(
      "input[name='car[crop_x]'], input[name='car[crop_y]'], input[name='car[crop_w]'], input[name='car[crop_h]']"
    ).forEach((field) => {
      field.value = ""
    })
  }

  renderStoredCropPreview(url) {
    const crop = this.storedCrop()
    if (!crop) return

    const image = new Image()
    image.onload = () => {
      const sourceWidth = image.naturalWidth
      const sourceHeight = image.naturalHeight
      const cropWidth = Math.max(1, Math.round(sourceWidth * crop.w))
      const cropHeight = Math.max(1, Math.round(sourceHeight * crop.h))
      const canvas = document.createElement("canvas")
      canvas.width = cropWidth
      canvas.height = cropHeight

      try {
        canvas.getContext("2d").drawImage(
          image,
          sourceWidth * crop.x,
          sourceHeight * crop.y,
          cropWidth,
          cropHeight,
          0,
          0,
          cropWidth,
          cropHeight
        )
        this.previewImgTarget.src = canvas.toDataURL()
        this.updateUpscalerVisibilityForSize(cropWidth, cropHeight)
      } catch (_error) {
        this.previewImgTarget.src = url
      }
    }
    image.onerror = () => {
      this.previewImgTarget.src = url
    }
    image.src = url
  }

  storedCrop() {
    const crop = {
      x: Number.parseFloat(this.cropFieldValue("crop_x")),
      y: Number.parseFloat(this.cropFieldValue("crop_y")),
      w: Number.parseFloat(this.cropFieldValue("crop_w")),
      h: Number.parseFloat(this.cropFieldValue("crop_h"))
    }

    if ([crop.x, crop.y, crop.w, crop.h].some((value) => Number.isNaN(value))) return null
    if (crop.w <= 0 || crop.h <= 0) return null

    const x = Math.max(0, Math.min(1, crop.x))
    const y = Math.max(0, Math.min(1, crop.y))

    return {
      x,
      y,
      w: Math.max(0, Math.min(1 - x, crop.w)),
      h: Math.max(0, Math.min(1 - y, crop.h))
    }
  }

  cropFieldValue(name) {
    return this.element.querySelector(`input[name='car[${name}]']`)?.value
  }

  get persistVariantComparisonVisible() {
    return this.hasUpscalerToggleTarget && this.upscalerToggleTarget.dataset.persistVisible === "true"
  }

  disablePersistedVariantComparison() {
    if (this.hasUpscalerToggleTarget) this.upscalerToggleTarget.dataset.persistVisible = "false"
  }
}
