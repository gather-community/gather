# frozen_string_literal: true

module Meals
  # Presents a select2 for filtering by a single user.
  class JobUserLens < ::UserLens
    protected

    def select2_context
      "meal_job_lens"
    end
  end
end
