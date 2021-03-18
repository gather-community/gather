# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for ensuring the event kind is entered by the reserver.
    class RequiresKindRule < Rule
      def check(event)
        event.kind.present? || [:kind, "can't be blank"]
      end
    end
  end
end
