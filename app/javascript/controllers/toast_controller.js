import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.removeAfterHidden = this.remove.bind(this)
    this.toast = new bootstrap.Toast(this.element, {
      autohide: true,
      delay: 5000
    })
    this.element.addEventListener("hidden.bs.toast", this.removeAfterHidden)
    this.toast.show()
  }

  disconnect() {
    this.element.removeEventListener("hidden.bs.toast", this.removeAfterHidden)
  }

  remove() {
    this.element.remove()
  }
}
