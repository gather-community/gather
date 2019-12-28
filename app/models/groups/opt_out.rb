# frozen_string_literal: true

module Groups
  # Represents a choice by a user to opt out of an 'everybody' group.
  class OptOut < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :group, inverse_of: :opt_outs
    belongs_to :user

    validate :from_affiliated_community

    private

    def from_affiliated_community
      return if group.communities.empty?
      errors.add(:user_id, :unaffiliated) unless group.communities.include?(user.community)
    end
  end
end
