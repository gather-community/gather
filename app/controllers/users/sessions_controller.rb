class Users::SessionsController < Devise::SessionsController
  def new
    redirect_to root_path
  end
end