class HomeController < ApplicationController
  def index
    # A landing page deve ser acessível para todos, mesmo logados.
    # O redirecionamento após login já é tratado no ApplicationController.
  end
end
