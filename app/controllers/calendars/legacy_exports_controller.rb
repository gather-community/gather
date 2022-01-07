# frozen_string_literal: true

module Calendars
  # Gen 1 and Gen 2 calendar exports
  class LegacyExportsController < ApplicationController
    include Exportable

    # Users are authenticated from the provided token for the personalized endpoint.
    prepend_before_action :authenticate_user_from_token!, only: :personalized

    # This is skipped to support legacy domains.
    skip_before_action :ensure_subdomain, only: :personalized

    # Community calendars are not user-specific. Authorization is handled by the policy class
    # based on the community calendar token.
    skip_before_action :authenticate_user!, only: :community

    # Community calendars are those where the current user is not known and the token
    # specifies the community only.
    # These routes should always have subdomain set, so current_community comes from that.
    def community
      policy = ExportPolicy.new(nil, current_community, community_token: params[:calendar_token])
      authorize_with_explict_policy_object(:community?, policy_object: policy)
      find_events_and_send(params[:type])
    end

    # Personalized calendars are those where the current user is known. They are authenticated by a token.
    # For legacy URLs the subdomain may not be specified, so we have to get the community from the user.
    def personalized
      self.current_community = current_user.community
      set_current_tenant(current_community.cluster)
      authorize(current_community, policy_class: ExportPolicy)
      find_events_and_send(params[:type])
    end

    protected

    # See def'n in ApplicationController for documentation.
    def community_for_route
      current_user.community if params[:action] == "personalized"
    end

    def export_file_basename
      params[:type]
    end

    private

    def find_events_and_send(type)
      case type
      when "all-meals" then find_all_meals_events_and_send
      when "community-meals" then find_community_meals_events_and_send
      when "your-meals", "meals" then find_your_meals_events_and_send
      when "community-events", "reservations" then find_community_events_and_send
      when "your-events", "your-reservations" then find_your_events_and_send
      when "your-jobs", "shifts" then find_your_jobs_events_and_send
      else raise ArgumentError, "unknown calendar type"
      end
    end

    def find_all_meals_events_and_send
      calendars = [
        System::CommunityMealsCalendar.find_by(community: current_community),
        System::OtherCommunitiesMealsCalendar.find_by(community: current_community)
      ]
      generate_ical_data_and_send("All Meals", calendars, false)
    end

    def find_community_meals_events_and_send
      calendars = [System::CommunityMealsCalendar.find_by(community: current_community)]
      generate_ical_data_and_send("#{current_community.name} Meals", calendars, false)
    end

    def find_your_meals_events_and_send
      calendars = [System::YourMealsCalendar.find_by(community: current_community)]
      generate_ical_data_and_send("Meals You're Attending", calendars, false)
    end

    def find_community_events_and_send
      calendars = Calendar.active.in_community(current_community).non_system.to_a
      generate_ical_data_and_send("#{current_community.name} Events", calendars, false)
    end

    def find_your_events_and_send
      calendars = Calendar.active.in_community(current_community).non_system.to_a
      generate_ical_data_and_send("Your Events", calendars, true)
    end

    def find_your_jobs_events_and_send
      calendars = [System::YourJobsCalendar.find_by(community: current_community)]
      generate_ical_data_and_send("Your Jobs", calendars, false)
    end

    def generate_ical_data_and_send(calendar_name, calendars, self_created_events_only)
      finder = EventFinder.new(calendars: calendars.compact, range: event_date_range,
                               user: current_user, own_only: self_created_events_only)
      send_calendar_data(calendar_name, finder.events)
    end
  end
end
