# frozen_string_literal: true

# A domain owned by one or more communities.
class Domain < ApplicationRecord
  # TEST THIS
  DOMAIN_REGEX = /\A([A-Z0-9]([A-Z0-9-]{0,61}[A-Z0-9])?)([.][A-Z0-9]([A-Z0-9-]{0,61}[A-Z0-9])?)*([.][A-Z0-9]([A-Z0-9-]{0,61}[A-Z0-9]))\z/i

  acts_as_tenant :cluster

  has_many :ownerships, class_name: "DomainOwnership", dependent: :destroy
  has_many :communities, through: :ownerships
  has_many :group_mailman_lists, class_name: "Groups::Mailman::List", dependent: :destroy

  # Matches domains that are in AT LEAST ALL the same communities as the passed array.
  scope :in_community, lambda { |c|
    where("EXISTS(SELECT id FROM domain_ownerships
      WHERE domain_id = domains.id AND community_id IN (?))", Array.wrap(c).map(&:id))
  }
  # Matches groups that are in AT LEAST ALL the same communities as the passed array.
  scope :in_communities, ->(cmtys) { cmtys.inject(all) { |rel, c| rel.in_community(c) } }
  scope :by_name, -> { alpha_order(:name) }

  validates :name, presence: true, format: {with: DOMAIN_REGEX}
  validate :name_unique_in_system
  validate :at_least_one_ownership

  private

  def name_unique_in_system
    return if name.blank?
    scope = self.class.where(name: name)
    scope = scope.where.not(id: id) if persisted?
    return if ActsAsTenant.without_tenant { scope.none? }
    errors.add(:name, :taken)
  end

  def at_least_one_ownership
    return if ownerships.reject(&:marked_for_destruction?).any?
    errors.add(:base, :at_least_one_ownership)
  end
end
