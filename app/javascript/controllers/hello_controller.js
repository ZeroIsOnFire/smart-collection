import { Controller } from "@hotwired/stimulus"
import { t } from "../i18n"

export default class extends Controller {
  connect() {
    this.element.textContent = t("hello")
  }
}
