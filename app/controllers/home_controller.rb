# frozen_string_literal: true

class HomeController < ApplicationController
  skip_before_action :check_subdomain
  skip_after_action :verify_authorized, only: :inactive

  def index
    skip_policy_scope

    # It's ok to fall back to the current user's community here because it's only for the purpose
    # of redirecting. This can happen if the user lands on https://gather.coop/.
    # In that case, we should redirect to https://USER_COMMUNITY.gather.coop/x,
    # where x is the default landing page.
    #
    # The only way to reach this controller is if the user is authenticated.
    community = current_community || current_user.community
    host = "#{community.slug}.#{Settings.url.host}"

    case community.settings.default_landing_page
    when "meals" then redirect_to(meals_url(host: host))
    when "directory" then redirect_to(users_url(host: host))
    when "calendars" then redirect_to(calendars_events_url(host: host))
    when "wiki" then redirect_to(wiki_pages_url(host: host))
    else redirect_to(users_url(host: host))
    end
  end

  def inactive
    redirect_to(root_path) if current_user.active?
  end
end
