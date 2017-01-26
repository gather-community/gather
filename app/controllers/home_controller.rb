class HomeController < ApplicationController
  def inactive
    skip_authorization
    redirect_to root_path if current_user.active?
  end
end
