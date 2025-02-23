# frozen_string_literal: true

module Groups
  # Joins a user to a group.
  class Membership < ApplicationRecord
    include Wisper.model

    KINDS = %i[manager joiner opt_out].freeze

    acts_as_tenant :cluster

    belongs_to :group, inverse_of: :memberships
    belongs_to :user, class_name: "::User"

    scope :managers, -> { where(kind: "manager") }
    scope :joiners, -> { where(kind: "joiner") }
    scope :opt_outs, -> { where(kind: "opt_out") }
    scope :positive, -> { where.not(kind: "opt_out") }
    scope :including_users_and_communities, -> { includes(:user).merge(::User.including_communities) }
    scope :by_kind_and_user_name, lambda {
      whens = KINDS.each_with_index.map { |k, i| "WHEN '#{k}' THEN #{i}" }.join(" ")
      joins(:user).order(Arel.sql("CASE kind #{whens} END")).merge(::User.by_name)
    }
    scope :by_group_name, -> { joins(:group).order("groups.name") }

    normalize_attributes :kind

    validates :user_id, presence: true
    validates :kind, presence: true
    validate :from_affiliated_community

    delegate :name, to: :group, prefix: true

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

      errors.add(:user_id, :unaffiliated) unless group.communities.include?(user&.community)
    end
  end
end
