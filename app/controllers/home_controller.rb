class HomeController < ApplicationController
  include HomeHelper
  skip_before_action :ensure_subdomain

  def inactive
    skip_authorization
    redirect_to root_path if current_user.active?
  end

  def index
    skip_policy_scope
    redirect_to_home_page(current_community)
  end
end
