# frozen_string_literal: true

Rails.application.routes.draw do
  get '/metrics', to: 'metrics#show'
  devise_for :users, controllers: { registrations: 'registrations' }

  patch '/locale', to: 'locales#update', as: :locale
  post '/cookie-consent', to: 'cookie_consents#create', as: :cookie_consent

  resource :initial_setup, only: %i[show update]

  # Removendo o redirecionamento automático para cars#index para que a landing page seja sempre a home
  # authenticated :user do
  #   root 'cars#index', as: :authenticated_root
  # end

  resources :cars do
    get :share_image, to: 'share_images#car'
    collection do
      patch :toggle_sharing
      patch :toggle_ai_upscaling
      patch :toggle_bulk_ai_upscaling
    end
  end

  resource :wishlist_export, only: :show, path: 'wishlist/export'
  get '/wishlist/share_image.png', to: 'share_images#wishlist', as: :wishlist_share_image
  get '/wishlist/public/:token/image.png', to: 'share_images#public_wishlist', as: :public_wishlist_share_image
  get '/wishlist/public/:token/items/:id/share_image', to: 'share_images#public_wishlist_item', as: :public_wishlist_item_share_image
  get '/wishlist/public/:token/items/:id', to: 'public_wishlists#item', as: :public_wishlist_item
  get '/wishlist/public/:token', to: 'public_wishlists#show', as: :public_wishlist
  resources :wishlist_items, path: 'wishlist' do
    patch :toggle_sharing, on: :collection
    post :add_to_collection, on: :member
    get :share_image, to: 'share_images#wishlist_item'
  end

  # Public sharing routes
  get '/s/:share_token', to: 'public_collections#index', as: :public_share
  get '/s/:share_token/car/:id/share_image', to: 'share_images#public_car', as: :public_car_share_image
  get '/s/:share_token/car/:id', to: 'public_collections#show', as: :public_share_car

  resources :autodetections, only: %i[create show destroy] do
    collection do
      post :detect_color
      post :classify
    end
    member do
      patch :retry
    end
    resources :detected_items, only: [:create]
  end

  resources :detected_items, only: [:destroy] do
    member do
      patch :reject
      patch :undo
      patch :update_selection
    end
  end

  resources :collection_exports, only: %i[create destroy] do
    get :status, on: :collection
  end

  root 'home#index'

  mount ActionCable.server => '/cable'

  namespace :admin do
    get '/', to: 'dashboard#index', as: :dashboard
    resources :users, except: %i[new create]
    get 'statistics', to: 'statistics#index'
    get 'maintenance', to: 'maintenance#index'
    post 'maintenance/cleanup', to: 'maintenance#cleanup'
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
