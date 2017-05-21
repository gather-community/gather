class HomeController < ApplicationController
  skip_before_action :ensure_subdomain
  
  def inactive
    skip_authorization
    redirect_to root_path if current_user.active?
  end
end
