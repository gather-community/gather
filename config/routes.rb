# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks",
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
      post :impersonate
      post :unimpersonate
    end
  end

  namespace :meals do
    resources :formulas do
      member do
        put :activate
        put :deactivate
      end
    end
  end

  get "/meals/reports", to: redirect("/meals/report") # Legacy path

  resources :meals do
    collection do
      get :jobs
      get :report
    end
    member do
      put :close
      put :reopen
      get :summary
    end

    resources :messages, only: %i[new create], module: :meals
    resource :finalize, only: %i[new create], module: :meals, controller: :finalize
  end

  namespace :reservations do
    resources :resources, except: :show do
      member do
        put :activate
        put :deactivate
      end
    end
  end

  resources :reservations

  resources :calendar_exports, only: :index, path: "calendars" do
    member do
      # This is the show action, allowing paths to include the user's calendar token,
      # e.g. /calendars/meals/558327a88c6a2c635fac627dcdbc50f4
      get ":calendar_token", to: "calendar_exports#show", as: ""
    end
    collection do
      put :reset_token
    end
  end

  resources :signups, only: %i[create update]

  resources :households do
    member do
      get :accounts
      put :activate
      put :deactivate
    end
  end

  resources :roles, only: :index

  resources :accounts, only: %i[index show edit update] do
    collection do
      put :apply_late_fees
    end
    resources :transactions, only: %i[index new create]
  end

  resources :statements, only: [:show] do
    collection do
      post :generate
      get :more
    end
  end

  resources :wiki_pages, controller: "wiki/pages", param: :slug, path: "wiki" do
    collection do
      get :all
    end
    member do
      get :history
      get :compare
    end
  end

  namespace :work do
    resources :shifts, path: :signups, only: %i[index show] do
      member do
        post :signup
        delete :unsignup
      end
    end
    resources :jobs
    resources :periods, except: :show
    get "report", to: "periods#report", as: :report
    get "/", to: redirect("/work/signups")
  end

  resources :uploads, only: %i[create destroy]

  namespace :admin do
    get "settings/:type", to: "settings#edit", as: :settings
    patch "settings/:type", to: "settings#update"
  end

  get "ping", to: "landing#ping"
  get "inactive", to: "home#inactive"
  get "signed-out", to: "landing#signed_out", as: :signed_out
  get "about/privacy-policy", to: "landing#privacy_policy"

  authenticated :user do
    root to: "home#index", as: :authenticated_root
  end

  root to: "landing#index"
end
