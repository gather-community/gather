# frozen_string_literal: true

module Calendars
  module Exports
    # Holds data for a single calendar event.
    class Event
      include ActiveModel::Model
      attr_accessor :obj_id, :starts_at, :ends_at, :location, :summary, :description, :url,
                    :kind_name, :uid_suffix
    end
  end
end
