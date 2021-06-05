# frozen_string_literal: true

module Calendars
  # Constructs an initial selection for a given user.
  class InitialSelection
    attr_accessor :selection

    def initialize(user:, calendar_scope:)
      self.selection = user.settings[:calendar_selection]
    end
  end
end
