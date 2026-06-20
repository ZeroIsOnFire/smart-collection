import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["gridButton", "listButton", "galleryButton"]
  static values = {
    storageKey: { type: String, default: "collection_view_preference" }
  }

  connect() {
    this.currentView = localStorage.getItem(this.storageKeyValue) || "grid"
    if (!this.allowedViews.includes(this.currentView)) this.currentView = "grid"
    this.applyView()
  }

  setGrid() {
    this.setView("grid")
  }

  setList() {
    this.setView("list")
  }

  setGallery() {
    this.setView("gallery")
  }

  setView(view) {
    if (!this.allowedViews.includes(view)) return

    this.currentView = view
    localStorage.setItem(this.storageKeyValue, view)
    this.applyView()
  }

  applyView() {
    this.element.classList.toggle("view-list", this.currentView === "list")
    this.element.classList.toggle("view-grid", this.currentView === "grid")
    this.element.classList.toggle("view-gallery", this.currentView === "gallery")

    this.updateButton(this.gridButtonTarget, this.currentView === "grid")
    this.updateButton(this.listButtonTarget, this.currentView === "list")
    if (this.hasGalleryButtonTarget) {
      this.updateButton(this.galleryButtonTarget, this.currentView === "gallery")
    }
  }

  updateButton(button, active) {
    button.classList.toggle("active", active)
    button.classList.toggle("text-primary", active)
    button.classList.toggle("text-muted", !active)
    button.setAttribute("aria-pressed", active.toString())
  }

  get allowedViews() {
    const views = ["grid", "list"]
    if (this.hasGalleryButtonTarget) views.push("gallery")

    return views
  }
}
