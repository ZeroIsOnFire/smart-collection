import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Quando o frame recebe conteúdo, abre o modal Bootstrap
    this._frameLoad = this.openModal.bind(this)
    this.element.addEventListener("turbo:frame-load", this._frameLoad)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this._frameLoad)
  }

  openModal() {
    const modalEl = document.getElementById("turboModal")
    if (!modalEl) return
    const modal = window.bootstrap.Modal.getOrCreateInstance(modalEl)
    modal.show()

    // Limpa o frame ao fechar o modal para evitar conteúdo stale
    modalEl.addEventListener("hidden.bs.modal", () => {
      this.element.innerHTML = ""
    }, { once: true })
  }
}
