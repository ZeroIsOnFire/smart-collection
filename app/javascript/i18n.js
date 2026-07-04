const translationsElement = document.getElementById("rails-i18n-data")

let config = {
  locale: "en",
  defaultLocale: "en",
  translations: {}
}

if (translationsElement) {
  config = JSON.parse(translationsElement.textContent)
}

function dig(object, path) {
  return path.split(".").reduce((value, key) => {
    if (value && typeof value === "object") {
      return value[key]
    }

    return undefined
  }, object)
}

function interpolate(message, options = {}) {
  if (typeof message !== "string") return message

  return message.replace(/%\{([^}]+)\}/g, (_match, key) => {
    return options[key] ?? `%{${key}}`
  })
}

function lookup(scope, locale) {
  return dig(config.translations?.[locale] || {}, scope)
}

const i18n = {
  locale: config.locale || "en",
  defaultLocale: config.defaultLocale || "en",
  translations: config.translations || {},
  t(scope, options = {}) {
    const message = lookup(scope, this.locale) ?? lookup(scope, this.defaultLocale)

    if (message === undefined) {
      return scope
    }

    return interpolate(message, options)
  }
}

window.I18n = i18n

const t = (scope, options = {}) => i18n.t(scope, options)

export { i18n, t }
