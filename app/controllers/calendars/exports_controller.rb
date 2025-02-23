# frozen_string_literal: true

module Calendars
  # Calendar exports
  class ExportsController < ApplicationController
    include Exportable

    # Users are authenticated from the provided token for the personalized endpoint.
    prepend_before_action :authenticate_user_from_calendar_token!, only: :personalized

    # Authentication happens via token and community calendars aren't user-authenticated.
    skip_before_action :authenticate_user!, only: :nonpersonalized

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
      send_calendar_data(calendar_name, finder.events)
    end

    # Nonpersonalized exports are those where the current user is not known and the token
    # specifies the community only.
    # current_community comes from the URL subdomain.
    def nonpersonalized
      policy = ExportPolicy.new(nil, current_community, community_token: params[:token])
      authorize_with_explict_policy_object(:community?, policy_object: policy)
      finder = EventFinder.new(calendars: calendars, range: event_date_range,
                               user: nil, own_only: false)
      send_calendar_data(calendar_name, finder.events)
    end

    def reset_token
      authorize(current_community, policy_class: ExportPolicy)
      current_user.reset_calendar_token!
      flash[:success] = "Token reset successfully."
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
          setting = current_user.settings["calendar_selection"]
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
      if params[:calendars] == "all"
        "All #{current_community.abbrv} Calendars"
      elsif calendars.size == 1
        "#{current_community.abbrv} #{calendars[0].name}"
      else
        "#{calendars.size} #{current_community.abbrv} Calendars"
      end
    end
  end
end
