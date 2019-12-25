# frozen_string_literal: true

module Groups
  # A group of users.
  class Group < ApplicationRecord
    KINDS = %i[committee subcommittee team task_force club crew squad gang group everybody].freeze
    AVAILABILITIES = %i[open closed hidden].freeze

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

    normalize_attributes :kind, :availability, :name

    accepts_nested_attributes_for :affiliations
    accepts_nested_attributes_for :memberships

    before_validation :normalize
    after_update { Work::ShiftIndexUpdater.new(self).update }

    validate :name_unique_in_all_communities
    validate :at_least_one_affiliation

    def everybody?
      kind == "everybody"
    end

    def closed?
      availability == "closed"
    end

    def open?
      availability == "open"
    end

    def hidden?
      availability == "hidden"
    end

    private

    def normalize
      memberships.delete(memberships.to_a.select(&:member?)) if everybody?
      self.availability = "open" if everybody?
    end

    def name_unique_in_all_communities
      return if name.blank?
      scope = self.class.where(name: name)
      scope = scope.where.not(id: id) if persisted?
      return if (communities & scope.to_a.flat_map(&:communities)).none?
      errors.add(:name, :taken)
    end

    def at_least_one_affiliation
      return if affiliations.reject(&:marked_for_destruction?).any?
      errors.add(:base, :at_least_one_affiliation)
    end
  end
end
