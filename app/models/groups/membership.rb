# frozen_string_literal: true

module Groups
  # Joins a user to a group.
  class Membership < ApplicationRecord
    KINDS = %i[manager joiner opt_out].freeze

    acts_as_tenant :cluster

    belongs_to :group, inverse_of: :memberships
    belongs_to :user

    scope :managers, -> { where(kind: "manager") }

    scope :by_kind_and_user_name, lambda {
      whens = KINDS.each_with_index.map { |k, i| "WHEN '#{k}' THEN #{i}" }.join(" ")
      joins(:user).order(Arel.sql("CASE kind #{whens} END")).merge(User.by_name)
    }

    normalize_attributes :kind

    validate :from_affiliated_community

    def joiner?
      kind == "joiner"
    end

    def manager?
      kind == "manager"
    end

    def opt_out?
      kind == "opt_out"
    end

    private

    def from_affiliated_community
      return if group.communities.empty?
      errors.add(:user_id, :unaffiliated) unless group.communities.include?(user.community)
    end
  end
end
