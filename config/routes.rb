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

  get "reservations(/:community(/:resource_id))" => "reservations#index",
    community: /[a-z][a-z0-9]?/, as: :reservations
  get "reservations/:community/:resource_id/new" => "reservations#new",
    community: /[a-z][a-z0-9]?/, as: :new_reservation
  resources :reservations, except: [:index, :new]

  resources :signups
  resources :households do
    member do
      get :accounts
      put :activate
      put :deactivate
    end
  end

  resources :accounts, only: [:index, :edit, :update] do
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

  get "ping", to: "landing#ping"
  get "inactive", to: "home#inactive"

  authenticated :user do
    root to: "meals#index", as: :authenticated_root
  end

  root to: "landing#index"
end
