import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search-form"
export default class extends Controller {
  static targets = ["input", "spinner", "results"]

  connect() {
    this.timeout = null
    this.initialValue = this.inputTarget.value.trim()
    
    // Ouvinte para reverter o estado de loading quando a requisição terminar
    this.element.addEventListener("turbo:submit-end", () => {
      this.hideSearchingState()
    })
  }

  submit(event) {
    // Evita o comportamento padrão do navegador que poderia causar refresh total
    if (event && event.type === 'submit') event.preventDefault()

    clearTimeout(this.timeout)

    const value = this.inputTarget.value.trim()
    
    // Não busca se o valor não mudou (evita disparos extras)
    if (value === this.initialValue) return
    this.initialValue = value

    this.timeout = setTimeout(() => {
      this.showSearchingState()
      
      // Submit the form via Turbo
      // O requestSubmit garante que o Turbo intercepte a submissão corretamente
      this.element.requestSubmit()
    }, 400)
  }

  showSearchingState() {
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.remove("d-none")
    
    const results = document.getElementById('cars_list_container')
    if (results) {
      results.style.opacity = '0.6'
    }
  }

  hideSearchingState() {
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.add("d-none")
    
    const results = document.getElementById('cars_list_container')
    if (results) {
      results.style.opacity = '1'
    }
  }
}
