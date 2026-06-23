import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "logo"]

  connect() {
    this.applyTheme(this.currentTheme)
  }

  // Called automatically by Stimulus whenever a new logo target enters the DOM
  // (including after Turbo Drive page navigations)
  logoTargetConnected(logo) {
    this.applyLogoSrc(logo, this.currentTheme)
  }

  // Called automatically by Stimulus whenever a new icon target enters the DOM
  iconTargetConnected(icon) {
    const theme = this.currentTheme
    if (theme === "dark") {
      icon.classList.replace("bi-moon-stars-fill", "bi-sun-fill")
    } else {
      icon.classList.replace("bi-sun-fill", "bi-moon-stars-fill")
    }
  }

  toggle() {
    const newTheme = this.currentTheme === "dark" ? "light" : "dark"
    this.applyTheme(newTheme)
    localStorage.setItem("theme", newTheme)
  }

  applyTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme)
    this.updateIcon(theme)
    this.updateButton(theme)
    this.updateLogos(theme)
  }

  updateButton(theme) {
    this.buttonTargets.forEach((button) => {
      button.setAttribute("aria-pressed", (theme === "dark").toString())
    })
  }

  updateIcon(theme) {
    if (!this.hasIconTarget) return

    if (theme === "dark") {
      this.iconTarget.classList.replace("bi-moon-stars-fill", "bi-sun-fill")
    } else {
      this.iconTarget.classList.replace("bi-sun-fill", "bi-moon-stars-fill")
    }
  }

  updateLogos(theme) {
    this.logoTargets.forEach((logo) => this.applyLogoSrc(logo, theme))
  }

  applyLogoSrc(logo, theme) {
    const darkSrc = logo.dataset.darkSrc || "/logo/logo-dark.png"
    const lightSrc = logo.dataset.lightSrc || "/logo/logo.png"
    logo.src = theme === "dark" ? `${window.location.origin}${darkSrc}` : `${window.location.origin}${lightSrc}`
  }

  get currentTheme() {
    const savedTheme = localStorage.getItem("theme")
    if (savedTheme) return savedTheme

    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }
}
