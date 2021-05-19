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
    resources :member_types, path: "member-types"
    resource :settings, only: %i[edit update]
    resources :memorials do
      resources :messages, only: %i[edit create update destroy], controller: "memorial_messages"
    end
    resource :password_change, only: %i[show edit update], path: "password-change" do
      patch :check
      post :strength
    end
  end

  resources :users do
    collection do
      patch :update_setting, path: "update-setting"
    end
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
    resources :signups, only: %i[create update]
    resources :formulas do
      member do
        put :activate
        put :deactivate
      end
    end
    resources :imports, only: %i[show new create]
    resources :roles, except: :show do
      member do
        put :activate
        put :deactivate
      end
    end
    resources :types, except: :show do
      collection do
        get :categories
      end
      member do
        put :activate
        put :deactivate
      end
    end
  end

  get "/meals/reports", to: redirect("/meals/report") # Legacy path

  resources :meals, controller: "meals/meals" do
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

  # `namespace :x` is just a shorthand for scope :x, module: :x, as: :x
  # scope :x adds /x/ as a URL prefix
  # scope module: :x adds /x as a controller prefix (controllers will be fetched under controllers/x/foo.rb)
  # scope as: :x adds the x as a prefix for path helpers
  # We just want controller and path helper prefixes
  scope as: :groups, module: :groups do
    resources :groups do
      member do
        put :activate
        put :deactivate
        put :join
        put :leave
      end
    end
  end

  namespace :groups do
    namespace :mailman do
      get "templates/:template_name/:list_id/:locale",
          to: "templates#show", constraints: { list_id: /.*/ }, defaults: {format: "text"}
    end
  end

  # Legacy calendar export routes. They are highly constrained.
  # These come first so they don't get gobbled up by more generic calendar routes below.
  get "calendars/:id/:calendar_token",
      to: "calendars/exports#personalized",
      constraints: {
        # These are the original calendar export types. Only these need to work for legacy URLs.
        id: /meals|community-meals|all-meals|shifts|reservations|your-reservations/,
        # These URLs should always have a 20 character token with alphanumeric chars plus - and _.
        # Enforcing this will make it easier to distinguish from other calendars routes in future.
        calendar_token: /[A-Za-z0-9_\-]{20}/,
        format: :ics
      }

  resources :calendars, except: :show, controller: "calendars/calendars" do
    member do
      put :activate
      put :deactivate
      put :move
    end
  end

  namespace :calendars do
    resources :events
    resources :protocols
    resources :groups, only: %i[new edit create update destroy]

    # index - The calendar export page
    resources :exports, only: :index do
      member do
        token_constraints = {calendar_token: /[A-Za-z0-9_\-]{20}/}.freeze

        # This is the personalized show action, allowing paths to include the user's calendar token,
        # e.g. /calendars/exports/meals/D7sbPv7YCUhxMs4Pyx9D.
        # The calendar's type gets captured as the :id param, so this is equivalent to
        # /calendars/exports/:id/:calendar_token
        get ":calendar_token", to: "exports#personalized", as: :personalized, constraints: token_constraints

        # This is the community show action, allowing paths to include the community's calendar token.
        # The community part is indicated by a leading +, e.g.
        # e.g. /calendars/exports/meals/+X7sbPv7YCUhxMs4Pyx9D.
        get "+:calendar_token", to: "exports#community", as: :community, constraints: token_constraints
      end
      collection do
        put :reset_token
      end
    end
  end

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

  resources :transactions, only: :index

  resources :statements, only: [:show] do
    collection do
      post :generate
      get :more
    end
  end

  namespace :billing do
    resources :templates, except: [:show] do
      collection do
        post :apply
        post :review
      end
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
    resources :periods do
      member do
        get :review_notices
        post :send_notices
      end
    end
    resource :settings, only: %i[edit update]
    get "report", to: "periods#report", as: :report
    get "/", to: redirect("/work/signups")
  end

  resources :uploads, only: :create

  namespace :admin do
    get "settings/:type", to: "settings#edit", as: :settings
    patch "settings/:type", to: "settings#update"
  end

  get "sso", to: "single_sign_on#sign_on"

  get "ping", to: "landing#ping"
  get "inactive", to: "home#inactive"
  get "about/:page", to: "landing#public_static"

  authenticated :user do
    root to: "home#index", as: :authenticated_root
  end

  root to: "landing#index"
end
