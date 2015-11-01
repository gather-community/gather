Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks",
    registrations: "users/registrations",
    sessions: "users/sessions"
  }

  resources :users do
    collection do
      get :invite
      post :send_invites, path: "send-invites"
    end
    member do
      put :activate
      put :deactivate
    end
  end

  resources :meals do
    collection do
      get :work
    end
    member do
      put :close
      put :reopen
      get :summary
    end
  end

  resources :signups
  resources :households do
    member do
      get :accounts
      put :activate
      put :deactivate
    end
  end

  resources :accounts, only: [:index, :show]
  resources :invoices, only: [:show] do
    collection do
      post :generate
    end
  end

  get "ping", to: "home#ping"

  authenticated :user do
    root to: "meals#index", as: :authenticated_root
  end

  root to: "home#index"
end
