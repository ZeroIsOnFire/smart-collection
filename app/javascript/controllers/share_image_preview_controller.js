import { Controller } from "@hotwired/stimulus"
import { t } from "../i18n"

export default class extends Controller {
  static targets = ["loading", "image", "message", "shareButton", "shareLabel"]
  static values = {
    filename: String,
    title: String
  }

  connect() {
    if (this.hasImageTarget && this.imageTarget.complete) this.loaded()
    this.configureShareButton()
  }

  loaded() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.add("d-none")
    if (this.hasImageTarget) this.imageTarget.classList.remove("opacity-0")
  }

  configureShareButton() {
    if (!this.hasShareButtonTarget) return

    if (this.canUseWebShare()) {
      this.shareButtonTarget.classList.remove("d-none")
    } else {
      this.shareButtonTarget.classList.add("d-none")
    }
  }

  async share() {
    if (!this.canUseWebShare()) return

    this.setSharing(true)
    this.setMessage("")

    try {
      const file = await this.shareableFile()

      if (file && this.canShareFiles([file])) {
        await navigator.share({
          title: this.titleValue,
          text: this.titleValue,
          files: [file]
        })
      } else {
        await navigator.share({
          title: this.titleValue,
          text: this.titleValue,
          url: this.absoluteImageUrl
        })
      }
    } catch (error) {
      if (error?.name !== "AbortError") {
        console.error(t("javascript.share_image_preview.errors.share_console"), error)
        this.setMessage(t("javascript.share_image_preview.errors.share_failed"))
      }
    } finally {
      this.setSharing(false)
    }
  }

  async shareableFile() {
    if (!this.hasImageTarget) return null

    const response = await fetch(this.absoluteImageUrl, { credentials: "same-origin" })
    if (!response.ok) return null

    const blob = await response.blob()
    if (!blob.type.startsWith("image/")) return null

    return new File([blob], this.filenameValue || "smart-collection-share.png", {
      type: blob.type || "image/png"
    })
  }

  canUseWebShare() {
    return typeof navigator !== "undefined" && typeof navigator.share === "function"
  }

  canShareFiles(files) {
    return typeof navigator.canShare === "function" && navigator.canShare({ files })
  }

  setSharing(isSharing) {
    if (!this.hasShareButtonTarget) return

    this.shareButtonTarget.disabled = isSharing
    if (this.hasShareLabelTarget) {
      this.shareLabelTarget.textContent = isSharing
        ? t("share_images.preview.sharing")
        : t("share_images.preview.share")
    }
  }

  setMessage(message) {
    if (!this.hasMessageTarget) return

    this.messageTarget.textContent = message
    this.messageTarget.classList.toggle("d-none", message.length === 0)
  }

  get absoluteImageUrl() {
    return new URL(this.imageTarget.currentSrc || this.imageTarget.src, window.location.href).toString()
  }
}
