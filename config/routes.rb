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
    end
  end

  resources :meals do
    collection do
      get :work
    end
  end

  resources :signups
  resources :households

  authenticated :user do
    root to: "meals#index", as: :authenticated_root
  end

  root to: "home#index"
end
