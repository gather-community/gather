# frozen_string_literal: true

module Calendars
  # Constructs an initial selection for a given user.
  class InitialSelection
    attr_accessor :selection

    def initialize(stored:, calendar_scope:)
      self.selection = stored || {}
      calendar_scope.each do |calendar|
        key = calendar.id.to_s
        selection[key] = calendar.selected_by_default unless selection.key?(key)
      end
    end
  end
end
