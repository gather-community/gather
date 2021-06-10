# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for showing a static notice at the top of the event form.
    class PreNoticeRule < Rule
      def check(_event)
        true
      end
    end
  end
end
