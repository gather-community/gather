# frozen_string_literal: true

module Reservations
  module Rules
    # Rule for showing a static notice at the top of the reservation form.
    class PreNoticeRule < Rule
      def check(_reservation)
        true
      end
    end
  end
end
