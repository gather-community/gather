# frozen_string_literal: true

# A single cohesive household group, not necessarily one-to-one with a unit.
class Household < ApplicationRecord
  include Deactivatable

  acts_as_tenant :cluster

  attr_writer :unit_num_and_suffix

  belongs_to :community
  has_many :accounts, -> { joins(:community).includes(:community).alpha_order(communities: :name) },
    inverse_of: :household, class_name: "Billing::Account"
  has_many :signups
  has_many :users, -> { by_name_adults_first }, inverse_of: :household, dependent: :destroy
  has_many :vehicles, class_name: "People::Vehicle", dependent: :destroy
  has_many :emergency_contacts, class_name: "People::EmergencyContact", dependent: :destroy
  has_many :pets, class_name: "People::Pet", dependent: :destroy

  scope :active, -> { where("deactivated_at IS NULL") }
  scope :by_name, -> { alpha_order(households: :name) }
  scope :by_unit, -> { order(:unit_num, :unit_suffix) }
  scope :by_active, -> { order("(CASE WHEN deactivated_at IS NULL THEN 0 ELSE 1 END)") }
  scope :ordered_by, ->(col) { col == "unit" ? by_unit : by_name }
  scope :by_commty_and_name, -> { joins(:community).alpha_order(communities: :abbrv).by_name }
  scope :in_community, ->(c) { where(community_id: c.id) }
  scope :matching, ->(q) { where("households.name ILIKE ?", "%#{q}%") }

  delegate :name, :abbrv, :cluster, to: :community, prefix: true

  validates :name, presence: true, length: {maximum: 32}, uniqueness: {scope: :community_id}
  validates :community_id, presence: true
  validates :unit_num_and_suffix, length: {maximum: 16}, allow_nil: true

  before_validation :split_unit_num_and_suffix

  accepts_nested_attributes_for :vehicles, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :emergency_contacts, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :pets, reject_if: :all_blank, allow_destroy: true

  normalize_attributes :name, :old_id, :old_name, :garage_nums

  def build_blank_associations
    vehicles.build if vehicles.empty?
    emergency_contacts.build if emergency_contacts.empty?
    pets.build if pets.empty?
  end

  # Returns users (including children) directly in the household PLUS any children associated by parentage,
  # even if they aren't directly in the household via the foreign key.
  def users_and_children
    (users + adults.map(&:children).flatten).uniq
  end

  def other_cluster_communities
    cluster.communities - [community]
  end

  def adults
    users.select(&:adult?)
  end

  def account_for(community)
    @accounts_by_community ||= {}
    @accounts_by_community[community] ||= accounts.find_by(community_id: community.id)
  end

  def credit_exceeded?(community)
    account_for(community).try(:credit_exceeded?) || false
  end

  def no_users?
    users.empty?
  end

  def garage_nums=(str)
    self[:garage_nums] = str.strip.blank? ? nil : str.split(/\s*,\s*/).join(", ")
  end

  def after_deactivate
    users.each(&:deactivate)
  end

  def user_activated
    activate
  end

  def user_deactivated
    deactivate(skip_callback: true) if users.all?(&:inactive?)
  end

  def unit_num_and_suffix
    [unit_num, unit_suffix].compact.join("-").presence
  end

  private

  def split_unit_num_and_suffix
    @unit_num_and_suffix = @unit_num_and_suffix&.strip

    # We don't use the reader method here because that would combine unit_num and unit_suffix.
    # We are only interested in parsing if a combined value has been given.
    return if @unit_num_and_suffix.blank?
    return unless (match = @unit_num_and_suffix.match(/\A(\d*)(.*)\z/))

    self.unit_num = match[1].presence&.strip

    # We strip leading - from suffix so that e.g. 20-2A ends up as [20,2A] instead of [20,-2A].
    self.unit_suffix = match[2].presence&.strip&.gsub(/\A-/, "")
  end
end
