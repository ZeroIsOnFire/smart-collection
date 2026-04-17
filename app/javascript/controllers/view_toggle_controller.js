import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["gridButton", "listButton"]

  connect() {
    this.currentView = localStorage.getItem("collection_view_preference") || "grid"
    this.applyView()
  }

  setGrid() {
    this.currentView = "grid"
    localStorage.setItem("collection_view_preference", "grid")
    this.applyView()
  }

  setList() {
    this.currentView = "list"
    localStorage.setItem("collection_view_preference", "list")
    this.applyView()
  }

  applyView() {
    if (this.currentView === "list") {
      this.gridButtonTarget.classList.remove("active", "text-primary")
      this.gridButtonTarget.classList.add("text-muted")
      
      this.listButtonTarget.classList.add("active", "text-primary")
      this.listButtonTarget.classList.remove("text-muted")
      
      this.element.classList.add("view-list")
      this.element.classList.remove("view-grid")
    } else {
      this.listButtonTarget.classList.remove("active", "text-primary")
      this.listButtonTarget.classList.add("text-muted")
      
      this.gridButtonTarget.classList.add("active", "text-primary")
      this.gridButtonTarget.classList.remove("text-muted")
      
      this.element.classList.add("view-grid")
      this.element.classList.remove("view-list")
    }
  }
}
