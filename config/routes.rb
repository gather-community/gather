Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks",
    registrations: "users/registrations"
  }

  devise_scope :user do
    delete "sign_out", to: "devise/sessions#destroy", as: :destroy_user_session
  end

  resources :users do
    collection do
      get :invite
      post :send_invites, path: "send-invites"
    end
    member do
      put :undelete
    end
  end

  resources :meals do
    collection do
      get :"work-calendar"
    end
  end

  resources :signups

  authenticated :user do
    root to: "meals#index", as: :authenticated_root
  end

  root to: "home#index"
end
