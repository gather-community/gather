# frozen_string_literal: true

module Calendars
  module Exports
    # Raises an error on construction if user not given.
    module UserRequiring
      extend ActiveSupport::Concern

      def initialize(user: nil, community: nil)
        raise Exports::TypeError, "This calendar type requires a user" if user.nil?
        super(user: user, community: community)
      end
    end
  end
end
