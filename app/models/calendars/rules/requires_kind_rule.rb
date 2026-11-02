# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for ensuring the event kind is entered by the creator.
    class RequiresKindRule < Rule
      def check(event)
        event.kind.present? || [:kind, I18n.t("errors.messages.blank")]
      end
    end
  end
end
