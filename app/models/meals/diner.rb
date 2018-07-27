# frozen_string_literal: true

module Meals
  # Models a single diner within a signup.
  # Will eventually be an AR model once future refactoring is complete.
  class Diner
    attr_accessor :kind

    def initialize(kind:)
      self.kind = kind
    end
  end
end
