# frozen_string_literal: true

module Groups
  # Joins a user to a group.
  class Membership < ApplicationRecord
    KINDS = %i[member manager].freeze

    acts_as_tenant :cluster

    belongs_to :group, inverse_of: :memberships
    belongs_to :user

    scope :managers, -> { where(kind: "manager") }

    # Kind alpha order of manager, member happens to work nicely
    scope :by_kind_and_user_name, -> { joins(:user).order(:kind).merge(User.by_name) }

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
