# frozen_string_literal: true

module Groups
  # A group of users.
  class Group < ApplicationRecord
    self.table_name = "groups"

    acts_as_tenant :cluster

    has_many :affiliations, class_name: "Groups::Affiliation", foreign_key: :group_id, dependent: :destroy,
                            inverse_of: :group
    has_many :communities, through: :affiliations
    has_many :memberships, class_name: "Groups::Membership", foreign_key: :group_id, dependent: :destroy,
                           inverse_of: :group
    has_many :users, through: :memberships

    scope :in_community, lambda { |c|
      where("EXISTS(SELECT id FROM group_affiliations
        WHERE group_id = groups.id AND community_id = ?)", c.id)
    }
    scope :can_request_jobs, -> { where(can_request_jobs: true) }
    scope :by_name, -> { alpha_order(:name) }

    after_update { Work::ShiftIndexUpdater.new(self).update }
  end
end
