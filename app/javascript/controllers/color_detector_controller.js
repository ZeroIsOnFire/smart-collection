import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "select", "preview"]
  static values = { colors: Object }

  connect() {
    this.updatePreview()
    this.canvas = document.createElement('canvas')
    this.canvas.width = 1
    this.canvas.height = 1
    this.ctx = this.canvas.getContext('2d', { willReadFrequently: true })
  }

  detect(event) {
    const file = event.target.files[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (e) => {
      const img = new Image()
      img.onload = () => {
        // Análise de Histograma simplificada no Frontend
        const sampleCanvas = document.createElement('canvas')
        const sampleCtx = sampleCanvas.getContext('2d')
        sampleCanvas.width = 50
        sampleCanvas.height = 50
        
        // Foca no centro 60% da imagem original para evitar bordas
        const sx = img.width * 0.2
        const sy = img.height * 0.2
        const sw = img.width * 0.6
        const sh = img.height * 0.6
        
        sampleCtx.drawImage(img, sx, sy, sw, sh, 0, 0, 50, 50)
        const pixels = sampleCtx.getImageData(0, 0, 50, 50).data
        
        const counts = {}
        let maxScore = -1
        let dominant = [0, 0, 0]

        for (let i = 0; i < pixels.length; i += 4) {
          const r = pixels[i]
          const g = pixels[i+1]
          const b = pixels[i+2]
          
          // Quantiza apenas para agrupamento no map
          const qr = Math.round(r / 15) * 15
          const qg = Math.round(g / 15) * 15
          const qb = Math.round(b / 15) * 15
          const key = `${qr},${qg},${qb}`
          
          counts[key] = (counts[key] || 0) + 1
          
          // Calcula Saturação p/ Score
          const maxC = Math.max(r, g, b)
          const minC = Math.min(r, g, b)
          const chroma = maxC - minC
          const sat = maxC === 0 ? 0 : (chroma / maxC)
          
          const score = counts[key] * (sat + 0.1)
          
          if (score > maxScore) {
            maxScore = score
            dominant = [r, g, b]
          }
        }
        
        const closest = this.findClosestColor(dominant[0], dominant[1], dominant[2])
        if (closest && this.hasSelectTarget) {
          this.selectTarget.value = closest
          this.updatePreview()
        }
      }
      img.src = e.target.result
    }
    reader.readAsDataURL(file)
  }

  findClosestColor(r, g, b) {
    let minDistance = Infinity
    let bestColor = null
    const colors = this.colorsValue

    for (const [name, hex] of Object.entries(colors)) {
      const hr = parseInt(hex.substring(1, 3), 16)
      const hg = parseInt(hex.substring(3, 5), 16)
      const hb = parseInt(hex.substring(5, 7), 16)

      const distance = Math.sqrt(Math.pow(r - hr, 2) + Math.pow(g - hg, 2) + Math.pow(b - hb, 2))
      
      if (distance < minDistance) {
        minDistance = distance
        bestColor = name
      }
    }

    return bestColor
  }

  updatePreview() {
    if (!this.hasSelectTarget || !this.hasPreviewTarget) return
    
    const selectedColorName = this.selectTarget.value
    const hex = this.colorsValue[selectedColorName] || 'transparent'
    
    this.previewTarget.style.backgroundColor = hex
    if (hex === 'transparent' || hex === '#FFFFFF') {
      this.previewTarget.style.border = '1px solid #dee2e6'
    } else {
      this.previewTarget.style.border = 'none'
    }
  }
}
