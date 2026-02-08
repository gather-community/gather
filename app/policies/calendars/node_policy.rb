# frozen_string_literal: true

module Calendars
  # Parent policy for both Groups and Calendars.
  class NodePolicy < ApplicationPolicy
    alias_method :node, :record

    class Scope < Scope
      def resolve
        # Only show active nodes unless admin.
        scope_with_visibility = active_admin? ? scope : scope.active

        # Need to load the calendars because access_level is computed by RuleSet which can't be computed
        # at database level.
        ids = scope_with_visibility.all.select do |node|
          next true if active_cluster_admin?
          next true if node.group?
          sample_event = Event.new(creator: user)
          sample_eventlet = Eventlet.new(event: sample_event, calendar: node)
          sample_eventlet.access_level(user.community) != "forbidden"
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
