import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loading", "image"]

  connect() {
    if (this.hasImageTarget && this.imageTarget.complete) this.loaded()
  }

  loaded() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.add("d-none")
    if (this.hasImageTarget) this.imageTarget.classList.remove("opacity-0")
  }
}
