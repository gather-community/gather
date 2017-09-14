class Users::SessionsController < Devise::OmniauthCallbacksController
  def new
    redirect_to "/"
  end
end
