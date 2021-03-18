# frozen_string_literal: true

module Calendars
  module Exports
    # Exports events created by user
    class YourEventsExport < EventsExport
      include UserRequiring

      protected

      def scope
        base_scope.where(reserver_id: user.id)
      end
    end
  end
end
