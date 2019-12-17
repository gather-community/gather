# frozen_string_literal: true

module Groups
  # Joins a user to a group.
  class Membership < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :group, inverse_of: :memberships
    belongs_to :user

    normalize_attributes :kind

    validate :from_affiliated_community

    def member?
      kind == "member"
    end

    def manager?
      kind == "manager"
    end

    private

    def from_affiliated_community
      return if group.communities.empty?
      errors.add(:user_id, :unaffiliated) unless group.communities.include?(user.community)
    end
  end
end
