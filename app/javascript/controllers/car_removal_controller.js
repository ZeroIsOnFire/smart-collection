import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { t } from "i18n"

export default class extends Controller {
  connect() {
    this.clickHandler = this.handleClick.bind(this)

    document.addEventListener("click", this.clickHandler, true)
  }

  disconnect() {
    document.removeEventListener("click", this.clickHandler, true)
  }

  handleClick(event) {
    const trigger = event.target.closest("[data-car-removal-trigger]")
    if (!trigger) return

    event.preventDefault()

    const form = trigger.closest("form")
    if (!form || form.dataset.carRemovalSubmitting === "true") return

    const confirmMessage = trigger.dataset.carRemovalConfirmMessage
    if (confirmMessage && !window.confirm(confirmMessage)) return

    const carId = trigger.dataset.carRemovalCarId
    form.dataset.carRemovalSubmitting = "true"
    form.dataset.carRemovalCarId = carId

    this.mark(carId)
    trigger.disabled = true
    this.closeModal(form)
    this.removeWithTurbo(form, carId)
  }

  async removeWithTurbo(form, carId) {
    try {
      const response = await fetch(form.action, {
        method: (form.getAttribute("method") || "post").toUpperCase(),
        headers: this.headers(),
        body: new FormData(form),
        credentials: "same-origin"
      })
      const body = await response.text()

      if (body.trim()) Turbo.renderStreamMessage(body)
      this.finish(form, carId, response.ok)
    } catch (error) {
      console.error(t("javascript.car_removal.errors.unexpected_console"), error)
      window.alert(t("javascript.car_removal.errors.unexpected"))
      this.finish(form, carId, false)
    }
  }

  mark(carId) {
    if (!carId) return

    this.matchingCards(carId).forEach((card) => {
      this.ensureLoader(card)
      card.classList.add("car-removal-pending")
      card.setAttribute("aria-busy", "true")
    })
  }

  finish(form, carId, success) {
    if (success) {
      this.matchingCards(carId).forEach((card) => card.remove())
      return
    }

    this.matchingCards(carId).forEach((card) => {
      card.classList.remove("car-removal-pending")
      card.removeAttribute("aria-busy")
    })
    form.dataset.carRemovalSubmitting = "false"
    form.querySelectorAll("[type='submit']").forEach((button) => {
      button.disabled = false
    })
  }

  matchingCards(carId) {
    return document.querySelectorAll(`[data-car-card-id="${this.escapeSelectorValue(carId)}"]`)
  }

  ensureLoader(card) {
    const cardElement = card.querySelector(".card")
    if (!cardElement || cardElement.querySelector(".car-removal-loader")) return

    const loader = document.createElement("div")
    loader.className = "car-removal-loader"
    loader.setAttribute("aria-hidden", "true")
    loader.innerHTML = `
      <div class="spinner-border text-primary" role="status">
        <span class="visually-hidden">${t("javascript.modal.loading")}</span>
      </div>
    `
    cardElement.append(loader)
  }

  closeModal(form) {
    if (!form.closest("#turboModal")) return

    const modalElement = document.getElementById("turboModal")
    const modal = modalElement ? window.bootstrap.Modal.getOrCreateInstance(modalElement) : null
    if (modal) modal.hide()
  }

  headers() {
    const headers = {
      Accept: "text/vnd.turbo-stream.html",
      "X-Requested-With": "XMLHttpRequest"
    }

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    if (csrfToken) headers["X-CSRF-Token"] = csrfToken

    return headers
  }

  escapeSelectorValue(value) {
    if (window.CSS?.escape) return window.CSS.escape(value)

    return String(value).replace(/["\\]/g, "\\$&")
  }
}
