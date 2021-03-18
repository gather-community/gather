# frozen_string_literal: true

module Calendars
  class CalendarPolicy < ApplicationPolicy
    alias calendar record

    class Scope < Scope
      def resolve
        # Only show active calendars unless admin.
        scope_with_visibility = active_admin? ? scope : scope.active

        # Need to load the calendars because access_level is computed by RuleSet which can't be computed
        # at database level.
        ids = scope_with_visibility.all.reject do |calendar|
          sample_event = Event.new(reserver: user, calendar: calendar)
          sample_event.access_level(user.community) == "forbidden"
        end.map(&:id)
        scope.where(id: ids)
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
      !calendar.events? && active_admin?
    end

    def activate?
      calendar.inactive? && active_admin?
    end

    def deactivate?
      calendar.active? && active_admin?
    end

    def permitted_attributes
      %i[default_calendar_view guidelines abbrv name meal_hostable
         photo_new_signed_id photo_destroy]
    end
  end
end
