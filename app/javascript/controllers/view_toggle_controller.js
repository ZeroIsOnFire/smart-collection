import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["gridButton", "listButton"]
  static values = {
    storageKey: { type: String, default: "collection_view_preference" }
  }

  connect() {
    this.currentView = localStorage.getItem(this.storageKeyValue) || "grid"
    if (!["grid", "list"].includes(this.currentView)) this.currentView = "grid"
    this.applyView()
  }

  setGrid() {
    this.setView("grid")
  }

  setList() {
    this.setView("list")
  }

  setView(view) {
    this.currentView = view
    localStorage.setItem(this.storageKeyValue, view)
    this.applyView()
  }

  applyView() {
    this.element.classList.toggle("view-list", this.currentView === "list")
    this.element.classList.toggle("view-grid", this.currentView === "grid")

    this.updateButton(this.gridButtonTarget, this.currentView === "grid")
    this.updateButton(this.listButtonTarget, this.currentView === "list")
  }

  updateButton(button, active) {
    button.classList.toggle("active", active)
    button.classList.toggle("text-primary", active)
    button.classList.toggle("text-muted", !active)
    button.setAttribute("aria-pressed", active.toString())
  }
}
