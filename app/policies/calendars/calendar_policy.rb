# frozen_string_literal: true

module Calendars
  class CalendarPolicy < NodePolicy
    alias calendar record

    class Scope < NodePolicy::Scope
      def resolve
        super.where(type: "Calendars::Calendar")
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
         photo_new_signed_id photo_destroy group_id]
    end
  end
end
