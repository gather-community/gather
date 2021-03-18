# frozen_string_literal: true

class HomeController < ApplicationController
  skip_before_action :ensure_subdomain
  skip_after_action :verify_authorized, only: :inactive

  def index
    skip_policy_scope
    return redirect_to(users_path) if current_community.nil?

    case current_community.settings.default_landing_page
    when "meals" then redirect_to(meals_path)
    when "directory" then redirect_to(users_path)
    when "calendars" then redirect_to(calendars_events_path)
    when "wiki" then redirect_to(wiki_pages_path)
    else redirect_to(users_path)
    end
  end

  def inactive
    redirect_to(root_path) if current_user.active?
  end
end
