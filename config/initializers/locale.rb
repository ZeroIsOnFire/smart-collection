# frozen_string_literal: true

# Configuração de Internacionalização (i18n)
#
# Locales disponíveis: pt-BR (padrão), en
#
# Para alternar o locale via URL, adicione ?locale=en ou ?locale=pt-BR.
# Para alternar via header HTTP, envie Accept-Language: en ou Accept-Language: pt-BR.
#
# Exemplo de uso no ApplicationController:
#
#   around_action :switch_locale
#
#   def switch_locale(&action)
#     locale = params[:locale] || I18n.default_locale
#     I18n.with_locale(locale, &action)
#   end

# Carregar todos os arquivos de locale recursivamente
I18n.load_path += Rails.root.glob('config/locales/**/*.{rb,yml}')

# Locales disponíveis
I18n.available_locales = %i[en pt-BR]

# Locale padrão
I18n.default_locale = :en

# Fallbacks: se uma tradução não existir em pt-BR, usa en
Rails.application.config.i18n.fallbacks = %i[en pt-BR]
