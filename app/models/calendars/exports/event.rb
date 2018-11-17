# frozen_string_literal: true

module Calendars
  module Exports
    # Holds data for a single calendar event.
    class Event
      include ActiveModel::Model
      attr_accessor :object_id, :starts_at, :ends_at, :location, :summary, :description, :url
    end
  end
end
