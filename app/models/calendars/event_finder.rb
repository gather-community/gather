# frozen_string_literal: true

module Calendars
  # Finds events on a given group of calendars over a given range
  class EventFinder
    include ActiveModel::Model

    attr_accessor :range, :user, :calendars, :own_only

    def events
      @events ||= normal_events + system_events
    end

    private

    def normal_events
      scope = EventPolicy::Scope.new(user, Event).resolve
        .between(range)
        .includes(:calendar)
        .where(calendar: non_system_calendars)
      scope = scope.where(creator: user).where(group: nil) if own_only
      scope.to_a
    end

    def system_events
      # If own_only is true, we exclude all system events because all such events are created by the system.
      return [] if own_only

      system_calendars.map { |c| c.events_between(range, actor: user) }.flatten
    end

    def non_system_calendars
      @non_system_calendars ||= calendars - system_calendars
    end

    def system_calendars
      @system_calendars ||= calendars.select(&:system?)
    end
  end
end
