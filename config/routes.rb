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
    resource :settings, only: %i[edit update]
    resources :signups, only: %i[create update]
    resources :assignments, only: %i[update destroy]
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
      get :reimbursee_paypal_email, path: "reimbursee-paypal-email"
    end
    member do
      put :close
      put :reopen
      get :summary
      put :unfinalize
    end

    resources :messages, only: %i[new create], module: :meals
    resource :finalize, only: %i[new create], module: :meals, controller: :finalize do
      member do
        get :complete
      end
    end
  end

  resources :meals, controller: "meals/meals_household_worker_change", path: "meals/worker-form",
    as: "meal_worker_form", only: :update

  # These routes are provided because Rails guesses meals_meal_path and meals_meals_path even
  # though we prefer meals_path (above) in code we write. Both this route and
  # the above one will lead to the same controller and URL.
  namespace :meals, path: "" do
    resources :meals
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
        to: "templates#show", constraints: {list_id: /.*/}, defaults: {format: "text"}

      resources :lists, only: [] do
        member do
          post :sync
        end
      end
    end
  end

  namespace :calendars do
    resources :events
    resources :protocols
    resources :groups, only: %i[new edit create update destroy]

    # These URLs should always have a 20 character token with alphanumeric chars plus - and _.
    # Enforcing this will make it easier to distinguish from other calendars routes in future.
    calendar_token_constraints = {token: /[A-Za-z0-9_-]{20}/}.freeze

    # Gen 1 legacy calendar export routes. They are highly constrained.
    # These come first so they don't get gobbled up by more generic calendar routes below.
    get ":type/:token",
      to: "legacy_exports#personalized",
      as: nil,
      constraints: calendar_token_constraints.merge(
        # These are the original calendar export types. Only these need to work for legacy URLs.
        type: /meals|community-meals|all-meals|shifts|reservations|your-reservations/
      )

    # Gen 2 legacy calendar export routes. These are resource-style because they assumed one calendar
    # per export.
    # This is the old export page that now shows a notice directing folks to the new one.
    get "exports/old", to: "legacy_exports#index", as: :legacy_exports
    put "exports/hide_legacy_links", to: "legacy_exports#hide_legacy_links", as: :hide_legacy_export_links

    # This is the personalized show action, allowing paths to include the user's calendar token,
    # e.g. /calendars/exports/meals/D7sbPv7YCUhxMs4Pyx9D.
    # The calendar's type gets captured as the :id param, so this is equivalent to
    # /calendars/exports/:type/:token
    get "exports/:type/:token",
      to: "legacy_exports#personalized",
      as: :personalized_exports,
      constraints: calendar_token_constraints.merge(
        type: /meals|your-meals|community-meals|all-meals|your-jobs|community-events|your-events/
      )

    # This is the community show action, allowing paths to include the community's calendar token.
    # The community part is indicated by a leading +, e.g.
    # e.g. /calendars/exports/meals/+X7sbPv7YCUhxMs4Pyx9D.
    get "exports/:type/+:token",
      to: "legacy_exports#nonpersonalized",
      as: :nonpersonalized_exports,
      constraints: calendar_token_constraints.merge(
        type: /community-meals|all-meals|community-events/
      )

    # Gen 3 (current) calendar export routes
    get "exports", to: "exports#index", constraints: {format: :html}
    get "community-export", to: "exports#nonpersonalized", constraints: {format: :ics}
    get "export", to: "exports#personalized", constraints: {format: :ics}
    put "exports/reset_token", to: "exports#reset_token"
  end

  resources :calendars, except: :show, controller: "calendars/calendars" do
    member do
      put :activate
      put :deactivate
      put :move
    end

    resources :events, controller: "calendars/events"
  end

  # These routes are provided because Rails guesses calendars_calendar_path and calendars_calendars_path even
  # though we prefer calendars_path (above) in code we write. Both these routes and
  # the above ones will lead to the same controller and URL.
  namespace :calendars, path: "" do
    resources :calendars do
      member do
        put :activate
        put :deactivate
        put :move
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

  namespace :gdrive do
    get "/", to: "browse#index", as: :home
    get "item/:item_id", to: "browse#index", as: :browse

    get "/config", to: "config#index", as: :config
    post "/config", to: "config#update"
    patch "/config", to: "config#update"

    resources :items, only: %i[new create destroy]
    resources :item_groups, path: "item-groups", only: %i[new create destroy]

    namespace :setup do
      get "auth/callback", to: "auth#callback", as: :auth_callback
      delete "auth/revoke", to: "auth#revoke", as: :auth_revoke
    end

    namespace :migration do
      resources :operations, only: %i[new edit create update destroy] do
        member do
          post "rescan"
        end
      end

      namespace :dashboard do
        get "/", to: redirect("/gdrive/migration/dashboard/status"), as: :home
        get "status", to: "status#show", as: :status

        # This is Devise.email_regexp without the anchor characters.
        resources :owners, only: %i[index show], id: /\S+@\S+\.\S+/, format: :html do
          collection do
            post :send_requests
          end
        end

        resources :files, only: %i[index]
        resources :logs, only: %i[index]
      end
      get "request/callback", to: "request#callback", as: :request_callback
      get "request/:token", to: "request#intro", as: :request
      get "request/:token/step1", to: "request#step1", as: :request_step1
      get "request/:token/step2", to: "request#step2", as: :request_step2
      get "request/:token/step3", to: "request#step3", as: :request_step3
      get "request/:token/step4", to: "request#step4", as: :request_step4
      get "request/:token/step5", to: "request#step5", as: :request_step5
      get "request/:token/finish", to: "request#finish", as: :request_finish
      get "request/:token/opt-out", to: "request#opt_out", as: :request_opt_out
      patch "request/:token/confirm-opt-out", to: "request#confirm_opt_out", as: :request_confirm_opt_out
      patch "request/:token/un-opt-out", to: "request#un_opt_out", as: :request_un_opt_out

      post "changes", to: "webhooks#changes", as: :changes_webhook
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

  namespace :subscription do
    get "/", to: "subscriptions#show"
    post "/start-payment", to: "subscriptions#start_payment", as: :start_payment
    get "/payment", to: "subscriptions#payment", as: :payment
    get "/success", to: "subscriptions#success", as: :success
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
