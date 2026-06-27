import { Controller } from "@hotwired/stimulus"
import { t } from "../i18n"

export default class extends Controller {
  connect() {
    this.frameLoad = this.openModal.bind(this)
    this.beforeFetchRequest = this.showLoadingForRequest.bind(this)
    this.beforeFrameRender = this.prepareForFrameRender.bind(this)
    this.fetchRequestError = this.showLoadingError.bind(this)
    this.frameMissing = this.showLoadingError.bind(this)
    this.beforeStreamRender = this.beforeStreamRenderHandler.bind(this)
    this.beforeCache = this.cleanupModalState.bind(this)
    this.submitStart = this.showLoadingForSubmit.bind(this)
    this.documentClick = this.handleDocumentClick.bind(this)

    this.element.addEventListener("turbo:frame-load", this.frameLoad)
    this.element.addEventListener("turbo:before-fetch-request", this.beforeFetchRequest)
    this.element.addEventListener("turbo:before-frame-render", this.beforeFrameRender)
    this.element.addEventListener("turbo:fetch-request-error", this.fetchRequestError)
    this.element.addEventListener("turbo:frame-missing", this.frameMissing)
    this.element.addEventListener("turbo:submit-start", this.submitStart)
    document.addEventListener("turbo:before-stream-render", this.beforeStreamRender)
    document.addEventListener("turbo:before-cache", this.beforeCache)
    document.addEventListener("click", this.documentClick)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.frameLoad)
    this.element.removeEventListener("turbo:before-fetch-request", this.beforeFetchRequest)
    this.element.removeEventListener("turbo:before-frame-render", this.beforeFrameRender)
    this.element.removeEventListener("turbo:fetch-request-error", this.fetchRequestError)
    this.element.removeEventListener("turbo:frame-missing", this.frameMissing)
    this.element.removeEventListener("turbo:submit-start", this.submitStart)
    document.removeEventListener("turbo:before-stream-render", this.beforeStreamRender)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    document.removeEventListener("click", this.documentClick)
  }

  openModal() {
    const modalElement = document.getElementById("turboModal")
    if (!modalElement) return

    const handleHidden = (event) => {
      if (event.target !== modalElement) return

      modalElement.removeEventListener("hidden.bs.modal", handleHidden)
      if (this.preserveFrameAfterHidden) {
        this.preserveFrameAfterHidden = false
      } else {
        this.element.innerHTML = ""
      }
      this.cleanupModalState()
    }

    modalElement.addEventListener("hidden.bs.modal", handleHidden)

    window.bootstrap.Modal.getOrCreateInstance(modalElement).show()
  }

  showLoadingForRequest(event) {
    if (event.target !== this.element) return
    if (this.skipNextLoading) {
      this.skipNextLoading = false
      return
    }

    const method = event.detail.fetchOptions?.method?.toUpperCase() || "GET"
    if (method === "GET") {
      this.lastNavigationUrl = event.detail.url || event.detail.fetchOptions?.url || this.element.getAttribute("src")
      this.showLoadingModal({ locked: true })
      return
    }

    this.showLoadingModal({ locked: true })
  }

  showLoadingForSubmit(event) {
    if (!this.element.contains(event.target)) return
    if (event.target.dataset.modalFrameSkipLoading === "true") {
      this.skipNextLoading = true
      return
    }

    this.showLoadingModal({ locked: true })
  }

  prepareForFrameRender() {
    this.hideLoadingModal()
  }

  showLoadingError(event) {
    if (event.target !== this.element) return

    event.preventDefault()
    this.showLoadingModal({ locked: true, error: true })
  }

  retryLoading() {
    if (!this.lastNavigationUrl) return

    this.element.src = this.lastNavigationUrl
  }

  handleDocumentClick(event) {
    if (event.target.closest("[data-modal-frame-retry]")) {
      event.preventDefault()
      this.retryLoading()
      return
    }

    if (event.target.closest("[data-modal-frame-close]")) {
      event.preventDefault()
      this.removeLoadingModal()
      this.cleanupModalState()
      return
    }
  }

  beforeStreamRenderHandler(event) {
    const stream = event.target
    if (stream.target !== this.element.id) return
    if (!["update", "replace"].includes(stream.action)) return

    event.preventDefault()
    const isEmptyStream = stream.templateElement?.content?.textContent.trim() === ""

    if (isEmptyStream) {
      this.hideLoadingModal()
      this.hideContentModal(() => {
        event.detail.render(stream)
        this.cleanupModalState()
      })
      return
    }

    this.hideLoadingModal()
    this.cleanupModalState({ force: true })
    event.detail.render(stream)

    requestAnimationFrame(() => {
      this.openModal()
      this.scrollToTopWhenInvalid()
    })
  }

  hideContentModal(afterHidden) {
    const modalElement = document.getElementById("turboModal")
    const modal = modalElement ? window.bootstrap.Modal.getInstance(modalElement) : null

    if (!modalElement || !modalElement.classList.contains("show") || !modal) {
      afterHidden()
      return
    }

    modalElement.addEventListener("hidden.bs.modal", afterHidden, { once: true })
    modal.hide()
  }

  showLoadingModal({ locked, error = false }) {
    this.hideVisibleContentModal()
    this.removeLoadingModal()
    document.body.insertAdjacentHTML("beforeend", this.loadingModalTemplate({ locked, error }))
    document.body.classList.add("modal-open")
  }

  hideVisibleContentModal() {
    const modalElement = document.getElementById("turboModal")
    if (!modalElement?.classList.contains("show")) return

    const modal = window.bootstrap.Modal.getInstance(modalElement)
    if (!modal) return

    this.preserveFrameAfterHidden = true
    modal.hide()
  }

  hideLoadingModal() {
    const modalElement = this.loadingModalElement()
    if (!modalElement) return

    this.removeLoadingModal()
    this.cleanupModalState()
  }

  removeLoadingModal() {
    this.loadingModalElement()?.remove()
  }

  loadingModalElement() {
    return document.getElementById("turboLoadingModal")
  }

  loadingModalTemplate({ locked, error = false } = {}) {
    return `
      <div class="turbo-loading-overlay" id="turboLoadingModal" role="dialog" aria-modal="true" aria-labelledby="turboLoadingModalLabel" data-loading-locked="${locked ? "true" : "false"}">
        <div class="turbo-loading-dialog turbo-car-modal-dialog">
          <div class="turbo-loading-content border-0 shadow-lg rounded-3 overflow-hidden">
            ${error ? this.loadingErrorTemplate() : this.loadingContentTemplate()}
          </div>
        </div>
      </div>
    `
  }

  loadingContentTemplate() {
    return `
      <div class="modal-body turbo-modal-loading-body p-4 p-md-5 text-center">
        <div class="spinner-border text-primary mb-3" role="status">
          <span class="visually-hidden">${t("javascript.modal.loading")}</span>
        </div>
        <h5 class="fw-bold mb-0" id="turboLoadingModalLabel">${t("javascript.modal.loading")}</h5>
      </div>
    `
  }

  loadingErrorTemplate() {
    return `
      <div class="modal-body turbo-modal-loading-body p-4 p-md-5 text-center">
        <div class="d-inline-flex align-items-center justify-content-center rounded-circle bg-danger bg-opacity-10 text-danger mb-3" style="width: 54px; height: 54px;">
          <i class="bi bi-exclamation-triangle fs-4"></i>
        </div>
        <h5 class="fw-bold mb-2" id="turboLoadingModalLabel">${t("javascript.modal.loading_error_title")}</h5>
        <p class="text-muted small mb-4">${t("javascript.modal.loading_error_description")}</p>
        <div class="d-flex justify-content-center gap-2 flex-wrap">
          <button type="button" class="btn btn-premium rounded-pill px-4" data-modal-frame-retry>
            <i class="bi bi-arrow-clockwise"></i>
            <span>${t("javascript.modal.retry")}</span>
          </button>
          <button type="button" class="btn btn-light rounded-pill px-4" data-modal-frame-close>
            <span>${t("javascript.modal.close")}</span>
          </button>
        </div>
      </div>
    `
  }

  scrollToTopWhenInvalid() {
    const modalElement = document.getElementById("turboModal")
    if (!modalElement) return
    if (!modalElement.querySelector(".invalid-feedback, .is-invalid, .alert-danger, .error_notification")) return

    const modalBody = modalElement.querySelector(".modal-body")
    if (modalBody) modalBody.scrollTo({ top: 0, behavior: "smooth" })
  }

  cleanupModalState(options = {}) {
    if (!options.force && (document.querySelector(".modal.show") || this.loadingModalElement())) return

    document.body.classList.remove("modal-open")
    document.body.style.removeProperty("overflow")
    document.body.style.removeProperty("padding-right")
    document.querySelectorAll(".modal-backdrop").forEach((element) => element.remove())
  }
}
