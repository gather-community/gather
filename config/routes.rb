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
      get :finalize
      put :do_finalize
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

  resources :accounts, only: [:index] do
    collection do
      put :apply_late_fees
      put :apply_payments
    end
    resources :transactions
  end

  resources :statements, only: [:show] do
    collection do
      post :generate
      get :more
    end
  end

  get "ping", to: "home#ping"

  authenticated :user do
    root to: "meals#index", as: :authenticated_root
  end

  root to: "home#index"
end
