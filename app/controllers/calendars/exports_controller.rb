# frozen_string_literal: true

module Calendars
  # Calendar exports
  class ExportsController < ApplicationController
    include Exportable

    # Users are authenticated from the provided token for the personalized endpoint.
    prepend_before_action :authenticate_user_from_calendar_token!, only: :personalized

    # Authentication happens via token and community calendars aren't user-authenticated.
    skip_before_action :authenticate_user!, only: :nonpersonalized

    # Calendar apps fetch these feeds without a person's browser behind the request, so they're rendered in
    # the default locale rather than whatever Accept-Language the calendar app happens to send.
    skip_around_action :switch_locale, only: %i[personalized nonpersonalized]

    def index
      skip_policy_scope
      authorize(current_community, policy_class: ExportPolicy)
      current_user.ensure_calendar_token!
      load_calendar_selection
    end

    def personalized
      authorize(current_community, :personalized?, policy_class: ExportPolicy)
      finder = EventFinder.new(calendars: calendars, range: event_date_range,
                               user: current_user, own_only: params[:own_only] == "1")
      send_calendar_data(calendar_name, finder.eventlets)
    end

    # Nonpersonalized exports are those where the current user is not known and the token
    # specifies the community only.
    # current_community comes from the URL subdomain.
    def nonpersonalized
      policy = ExportPolicy.new(nil, current_community, community_token: params[:token])
      authorize_with_explict_policy_object(:community?, policy_object: policy)
      finder = EventFinder.new(calendars: calendars, range: event_date_range,
                               user: nil, own_only: false)
      send_calendar_data(calendar_name, finder.eventlets)
    end

    def reset_token
      authorize(current_community, policy_class: ExportPolicy)
      current_user.reset_calendar_token!
      flash[:success] = t("calendars.token_reset")
      redirect_to(calendars_exports_path)
    end

    protected

    def export_file_basename
      "calendars"
    end

    private

    def load_calendar_selection
      calendar_scope = policy_scope(Node).in_community(current_community).active
      @calendars = calendar_scope.arrange(decorator: CalendarDecorator)
      @calendar_selection =
        # If a single calendar is requested, honor that.
        if params[:calendar_id]
          {params[:calendar_id] => true}
        else
          # Include the old, non-scoped key for backwards compatibility during deploy.
          setting = current_user.settings["calendar_selection_#{current_community.id}"] ||
                    current_user.settings["calendar_selection"]
          InitialSelection.new(stored: setting, calendar_scope: calendar_scope).selection
        end
    end

    def calendars
      return @calendars if @calendars
      calendar_scope = Calendar.in_community(current_community)
      @calendars = if params[:calendars] == "all"
                     calendar_scope.to_a
                   else
                     calendar_scope.where(id: params[:calendars].split(" ")).to_a
                   end
    end

    def calendar_name
      abbrv = current_community.abbrv
      if params[:calendars] == "all"
        t("calendars.feed_names.all", community: abbrv)
      elsif calendars.size == 1
        t("calendars.feed_names.single", community: abbrv, calendar: calendars[0].name)
      else
        t("calendars.feed_names.multiple", community: abbrv, count: calendars.size)
      end
    end
  end
end
