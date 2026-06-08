import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["gridButton", "listButton", "carouselButton", "carouselPanel"]
  static values = {
    carouselEnabled: Boolean,
    storageKey: { type: String, default: "collection_view_preference" }
  }

  connect() {
    this.currentView = localStorage.getItem(this.storageKeyValue) || "grid"
    if (this.currentView === "carousel" && !this.carouselEnabledValue) this.currentView = "grid"
    this.applyView()
  }

  setGrid() {
    this.setView("grid")
  }

  setList() {
    this.setView("list")
  }

  setCarousel() {
    if (!this.carouselEnabledValue) return

    this.setView("carousel")
  }

  setView(view) {
    this.currentView = view
    localStorage.setItem(this.storageKeyValue, view)
    this.applyView()
  }

  applyView() {
    this.element.classList.toggle("view-list", this.currentView === "list")
    this.element.classList.toggle("view-grid", this.currentView === "grid")
    this.element.classList.toggle("view-carousel", this.currentView === "carousel")

    this.updateButton(this.gridButtonTarget, this.currentView === "grid")
    this.updateButton(this.listButtonTarget, this.currentView === "list")

    if (this.hasCarouselButtonTarget) {
      this.updateButton(this.carouselButtonTarget, this.currentView === "carousel")
    }

    if (this.hasCarouselPanelTarget) {
      this.carouselPanelTarget.classList.toggle("d-none", this.currentView !== "carousel")
    }
  }

  updateButton(button, active) {
    button.classList.toggle("active", active)
    button.classList.toggle("text-primary", active)
    button.classList.toggle("text-muted", !active)
    button.setAttribute("aria-pressed", active.toString())
  }
}
