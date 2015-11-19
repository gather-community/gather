class Household < ActiveRecord::Base
  include Deactivatable

  belongs_to :community
  has_many :credit_limits, dependent: :destroy
  has_many :accounts, ->{ joins(:community).includes(:community).order("communities.name") },
    inverse_of: :household
  has_many :signups
  has_many :users, ->{ by_name }

  scope :active, -> { where("deactivated_at IS NULL") }
  scope :by_name, -> { order("households.name") }
  scope :by_active_and_name, -> { order("(CASE WHEN deactivated_at IS NULL THEN 0 ELSE 1 END)").by_name }
  scope :by_commty_and_name, -> { includes(:community).order("communities.abbrv").by_name }
  scope :in_community, ->(c) { where(community_id: c.id) }
  scope :matching, ->(q) { where("households.name ILIKE ?", "%#{q}%") }

  delegate :name, :abbrv, to: :community, prefix: true

  validates :name, presence: true, length: { maximum: 32 },
    uniqueness: { scope: :community_id, message:
      "There is already a household with this name at this community" }
  validates :community_id, presence: true
  validates :unit_num, length: { maximum: 8 }

  normalize_attributes :name, :unit_num, :old_id, :old_name

  def no_users?
    users.empty?
  end

  def full_name
    "#{community.abbrv}: #{name}"
  end

  def name
    "#{read_attribute(:name)}" << (active? ? "" : " (Inactive)")
  end

  def over_limit?(community)
    credit_limits.find_by(community: community).try(:exceeded?) || false
  end

  def after_deactivate
    users.each(&:deactivate!)
  end

  def user_activated
    activate!
  end

  def user_deactivated
    deactivate!(skip_callback: true) if users.all?(&:inactive?)
  end

  def any_assignments?
    users.any?(&:any_assignments?)
  end

  def any_signups?
    signups.any?
  end

  def any_users?
    users.any?
  end

  def any_line_items?
    accounts.any?{ |a| a.line_items.any? }
  end

  def any_statements?
    accounts.any?{ |a| a.statements.any? }
  end

  def from_grot?
    old_id.present? || old_name.present?
  end
end
