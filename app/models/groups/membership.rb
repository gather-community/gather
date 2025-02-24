# frozen_string_literal: true

module Groups
# == Schema Information
#
# Table name: group_memberships
#
#  id         :bigint           not null, primary key
#  kind       :string(32)       default("joiner"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :bigint           not null
#  group_id   :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_group_memberships_on_cluster_id            (cluster_id)
#  index_group_memberships_on_group_id              (group_id)
#  index_group_memberships_on_group_id_and_user_id  (group_id,user_id) UNIQUE
#  index_group_memberships_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (group_id => groups.id)
#  fk_rails_...  (user_id => users.id)
#
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
