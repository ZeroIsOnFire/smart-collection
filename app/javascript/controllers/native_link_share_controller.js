import { Controller } from "@hotwired/stimulus"
import { t } from "../i18n"

export default class extends Controller {
  static targets = ["button", "label", "message"]
  static values = {
    title: String,
    text: String,
    url: String
  }

  connect() {
    if (!this.hasButtonTarget) return

    if (this.canShare()) {
      this.buttonTarget.classList.remove("d-none")
    } else {
      this.buttonTarget.classList.add("d-none")
    }
  }

  async share() {
    if (!this.canShare()) return

    this.setSharing(true)
    this.setMessage("")

    try {
      await navigator.share({
        title: this.titleValue,
        text: this.textValue || this.titleValue,
        url: this.shareUrl
      })
    } catch (error) {
      if (error?.name !== "AbortError") {
        console.error(t("javascript.native_link_share.errors.share_console"), error)
        this.setMessage(t("javascript.native_link_share.errors.share_failed"))
      }
    } finally {
      this.setSharing(false)
    }
  }

  canShare() {
    return typeof navigator !== "undefined" && typeof navigator.share === "function"
  }

  setSharing(isSharing) {
    this.buttonTarget.disabled = isSharing

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = isSharing
        ? t("javascript.native_link_share.sharing")
        : t("javascript.native_link_share.share")
    }
  }

  setMessage(message) {
    if (!this.hasMessageTarget) return

    this.messageTarget.textContent = message
    this.messageTarget.classList.toggle("d-none", message.length === 0)
  }

  get shareUrl() {
    return this.urlValue || window.location.href
  }
}
