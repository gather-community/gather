# frozen_string_literal: true

module Calendars
  class CalendarPolicy < NodePolicy
    alias calendar record

    class Scope < NodePolicy::Scope
      # Returns an Array of calendars within the given scope that
      # the user can create events on, according to the EventPolicy.
      def resolve_for_create
        resolve.select do |calendar|
          sample_event = Event.new(calendar: calendar, creator: user)
          EventPolicy.new(user, sample_event).create?
        end
      end
    end

    def index?
      active_admin?
    end

    def show?
      active_admin?
    end

    def create?
      active_admin?
    end

    def update?
      active_admin?
    end

    def destroy?
      !calendar.events? && !calendar.system? && active_admin?
    end

    def activate?
      calendar.inactive? && active_admin?
    end

    def deactivate?
      calendar.active? && active_admin?
    end

    def permitted_attributes
      base = %i[default_calendar_view abbrv name color
                photo_new_signed_id photo_destroy group_id selected_by_default]
      base.concat(%i[meal_hostable guidelines allow_overlap]) unless calendar.system?
      base
    end
  end
end
