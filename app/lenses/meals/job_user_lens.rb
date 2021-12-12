# frozen_string_literal: true

module Meals
  # Presents a select2 for filtering by a single user.
  class JobUserLens < ::UserLens
    protected

    def select2_context
      "current_community_all"
    end
  end
end
