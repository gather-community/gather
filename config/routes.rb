# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, path: "people/users",
                     path_names: {sign_in: "sign-in", sign_out: "sign-out"},
                     controllers: {
                       sessions: "people/users/sessions",
                       omniauth_callbacks: "people/users/omniauth_callbacks",
                       passwords: "people/users/passwords",
                       confirmations: "people/users/confirmations"
                     }
  get "people/users/signed-out", to: "landing#signed_out", as: :user_signed_out

  resources :communities, only: :index

  namespace :people do
    resources :sign_in_invitations, path: "sign-in-invitations", only: %i[new create]
    resources :birthdays, only: :index
    resources :vehicles, only: :index
    resource :password_change, only: %i[show edit update], path: "password-change" do
      patch :check
      post :strength
    end
  end

  resources :users do
    member do
      put :activate
      put :deactivate
      put :resend_email_confirmation
      delete :cancel_email_change
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
    resources :roles, except: :show do
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
      get :worker_form, path: "worker-form"
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
    resources :protocols
  end

  resources :reservations, controller: "reservations/reservations"

  # Legacy calendar routes
  get "calendars/:id/:calendar_token",
    to: "calendars/exports#personalized",
    constraints: {
      # These are the original calendar export types. Only these need to work for legacy URLs.
      id: /meals|community-meals|all-meals|shifts|reservations|your-reservations/,
      # These URLs should always have a 20 character token with alphanumeric chars plus - and _.
      # Enforcing this will make it easier to distinguish from other calendars routes in future.
      calendar_token: /[A-Za-z0-9_\-]{20}/
    }

  namespace :calendars do
    # index - The calendar export page
    resources :exports, only: :index do
      member do
        token_constraints = {calendar_token: /[A-Za-z0-9_\-]{20}/}.freeze

        # This is the personalized show action, allowing paths to include the user's calendar token,
        # e.g. /calendars/meals/D7sbPv7YCUhxMs4Pyx9D.
        # The calendar's type gets captured as the :id param, so this is equivalent to
        # /calendars/:id/:calendar_token
        get ":calendar_token", to: "exports#personalized", as: :personalized, constraints: token_constraints

        # This is the community show action, allowing paths to include the community's calendar token.
        # The community part is indicated by a leading +, e.g.
        # e.g. /calendars/meals/+X7sbPv7YCUhxMs4Pyx9D.
        get "+:calendar_token", to: "exports#community", as: :community, constraints: token_constraints
      end
      collection do
        put :reset_token
      end
    end
  end

  resources :calendar_exports, only: :index, path: "calendars", controller: "calendars/exports"

  resources :signups, only: %i[create update]

  resources :households do
    member do
      put :activate
      put :deactivate
    end
  end

  resources :roles, only: :index

  resources :accounts, only: %i[index show edit update] do
    collection do
      get :yours
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
  get "about/:page", to: "landing#public_static"

  authenticated :user do
    root to: "home#index", as: :authenticated_root
  end

  root to: "landing#index"
end
