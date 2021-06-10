# frozen_string_literal: true

module Calendars
  # Finds events on a given group of calendars over a given range
  class EventFinder
    include ActiveModel::Model

    attr_accessor :range, :user, :calendars

    def events
      @events ||= normal_events + system_events
    end

    private

    def normal_events
      EventPolicy::Scope.new(user, Event).resolve
        .between(range)
        .includes(:calendar)
        .where(calendar: non_system_calendars).to_a
    end

    def system_events
      system_calendars.map { |c| c.events_between(range, user: user) }.flatten
    end

    def non_system_calendars
      @non_system_calendars ||= calendars - system_calendars
    end

    def system_calendars
      @system_calendars ||= calendars.select(&:system?)
    end
  end
end
