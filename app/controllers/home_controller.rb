class HomeController < ApplicationController
  skip_before_action :ensure_subdomain

  def index
    skip_policy_scope
    return redirect_to users_path if current_community.nil?

    case current_community.settings.default_landing_page
    when "meals" then redirect_to meals_path
    when "directory" then redirect_to users_path
    when "reservations" then redirect_to reservations_path
    when "wiki" then redirect_to wiki_pages_path
    else redirect_to users_path end
  end

  def inactive
    skip_authorization
    redirect_to root_path if current_user.active?
  end
end
