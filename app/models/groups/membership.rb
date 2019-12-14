# frozen_string_literal: true

module Groups
  # Joins a user to a group.
  class Membership < ApplicationRecord
    belongs_to :group, inverse_of: :memberships
    belongs_to :user
  end
end
