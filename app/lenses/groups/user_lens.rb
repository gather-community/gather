# frozen_string_literal: true

module Groups
  # Presents a select2 for filtering by a single user.
  class UserLens < ::UserLens
    protected

    def select2_context
      "current_cluster_adults"
    end
  end
end
