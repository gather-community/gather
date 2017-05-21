Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks",
    registrations: "users/registrations"
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
      get :jobs
      get :reports
    end
    member do
      put :close
      put :reopen
      get :finalize
      put :do_finalize
      get :summary
    end
  end

  resources :reservations

  resources :calendar_exports, only: [:index], path: "calendars" do
    member do
      # This is the show action, allowing paths to include the user's calendar token,
      # e.g. /calendars/meals/558327a88c6a2c635fac627dcdbc50f4
      get ":calendar_token", to: "calendar_exports#show", as: ""
    end
    collection do
      put :reset_token
    end
  end

  resources :signups, only: [:create, :update]

  resources :households do
    member do
      get :accounts
      put :activate
      put :deactivate
    end
  end

  resources :accounts, only: [:index, :show, :edit, :update] do
    collection do
      put :apply_late_fees
    end
    resources :transactions
  end

  resources :statements, only: [:show] do
    collection do
      post :generate
      get :more
    end
  end

  resources :uploads, only: [:create, :destroy]

  namespace :admin do
    get "settings/:type", to: "settings#edit", as: :settings
    patch "settings/:type", to: "settings#update"
  end

  get "ping", to: "landing#ping"
  get "inactive", to: "home#inactive"
  get "signed-out", to: "landing#signed_out", as: :signed_out
  get "about/privacy-policy", to: "landing#privacy_policy"

  authenticated :user do
    root to: "users#index", as: :authenticated_root
  end

  root to: "landing#index"
end
