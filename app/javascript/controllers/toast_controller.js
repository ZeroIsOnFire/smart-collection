import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.toast = new bootstrap.Toast(this.element, {
      autohide: true,
      delay: 5000
    })
    this.toast.show()
  }
}
