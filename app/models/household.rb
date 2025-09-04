# frozen_string_literal: true

# == Schema Information
#
# Table name: households
#
#  id             :integer          not null, primary key
#  alternate_id   :string
#  cluster_id     :integer          not null
#  community_id   :integer          not null
#  created_at     :datetime         not null
#  deactivated_at :datetime
#  garage_nums    :string
#  keyholders     :string
#  member_type_id :bigint
#  name           :string(50)       not null
#  unit_num       :integer
#  unit_suffix    :string
#  updated_at     :datetime         not null
#
# A single cohesive household group, not necessarily one-to-one with a unit.
class Household < ApplicationRecord
  include Wisper.model
  include Deactivatable
  include SemicolonDisallowable

  acts_as_tenant :cluster

  belongs_to :community
  belongs_to :member_type, class_name: "People::MemberType", inverse_of: :households
  has_many :accounts, -> { joins(:community).includes(:community).alpha_order(communities: :name) },
           inverse_of: :household, class_name: "Billing::Account", dependent: :destroy
  has_many :signups, class_name: "Meals::Signup", dependent: :destroy
  has_many :users, -> { by_name_adults_first }, inverse_of: :household, dependent: :destroy
  has_many :vehicles, class_name: "People::Vehicle", dependent: :destroy
  has_many :emergency_contacts, class_name: "People::EmergencyContact", dependent: :destroy
  has_many :pets, class_name: "People::Pet", dependent: :destroy

  scope :active, -> { where("deactivated_at IS NULL") }
  scope :by_name, -> { alpha_order(households: :name) }
  scope :by_unit, -> { order(:unit_num, :unit_suffix) }
  scope :ordered_by, ->(col) { col == "unit" ? by_unit : by_name }
  scope :by_commty_and_name, -> { joins(:community).alpha_order(communities: :abbrv).by_name }
  scope :in_community, ->(c) { where(community_id: c.id) }
  scope :matching, ->(q) { where("households.name ILIKE ?", "%#{q}%") }

  delegate :name, :abbrv, :cluster, to: :community, prefix: true

  validates :name, presence: true, length: {maximum: 32}, uniqueness: {scope: :community_id}
  validates :community_id, presence: true
  validates :unit_num_and_suffix, length: {maximum: 16}, allow_nil: true

  disallow_semicolons :name

  after_deactivate { users.each(&:deactivate) }

  accepts_nested_attributes_for :vehicles, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :emergency_contacts,
    allow_destroy: true,
    reject_if: ->(attrs) { attrs.all? { |k, v| k == "_destroy" || k == "country_code" || v.blank? } }
  accepts_nested_attributes_for :pets, reject_if: :all_blank, allow_destroy: true

  normalize_attributes :name, :old_id, :old_name, :garage_nums

  def build_blank_associations
    vehicles.build if vehicles.empty?
    emergency_contacts.build if emergency_contacts.empty?
    pets.build if pets.empty?
  end

  def other_cluster_communities
    cluster.communities - [community]
  end

  def adults
    users.select(&:adult?)
  end

  def full_access_users
    users.select(&:full_access?)
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

  def user_activated
    activate
  end

  def user_deactivated
    deactivate(skip_callback: true) if users.all?(&:inactive?)
  end

  def unit_num_and_suffix
    [unit_num, unit_suffix].compact.join("-").presence
  end

  def unit_num_and_suffix=(str)
    str = str&.strip

    # We don't use the reader method here because that would combine unit_num and unit_suffix.
    # We are only interested in parsing if a combined value has been given.
    return if str.blank?
    return unless (match = str.match(/\A(\d*)(.*)\z/))

    self.unit_num = match[1].presence&.strip

    # We strip leading - from suffix so that e.g. 20-2A ends up as [20,2A] instead of [20,-2A].
    self.unit_suffix = match[2].presence&.strip&.gsub(/\A-/, "")
  end
end
