# frozen_string_literal: true

module Calendars
  module Exports
    # Exports all events in community
    class CommunityEventsExport < EventsExport
      protected

      def scope
        base_scope
      end
    end
  end
end
