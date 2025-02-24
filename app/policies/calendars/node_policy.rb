# frozen_string_literal: true

module Calendars
  class NodePolicy < ApplicationPolicy
    alias node record

    class Scope < Scope
      def resolve
        # Only show active nodes unless admin.
        scope_with_visibility = active_admin? ? scope : scope.active

        # Need to load the calendars because access_level is computed by RuleSet which can't be computed
        # at database level.
        ids = scope_with_visibility.all.reject do |node|
          next false if node.group?

          sample_event = Event.new(creator: user, calendar: node)
          sample_event.access_level(user.community) == "forbidden"
        end.map(&:id)
        scope.where(id: ids)
      end
    end

    def index?
      active_admin?
    end

    def move?
      active_admin?
    end
  end
end
