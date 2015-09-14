class Household < ActiveRecord::Base
  belongs_to :community
  has_many :credit_limits
  has_many :users

  scope :by_name, -> { order("households.name") }
  scope :by_commty_and_name, -> { includes(:community).order("communities.abbrv, households.name") }
  scope :matching, ->(q) { where("households.name ILIKE ?", "%#{q}%") }

  delegate :name, :abbrv, to: :community, prefix: true

  validates :name, presence: true, length: { maximum: 32 }
  validates :community_id, presence: true
  validates :unit_num, length: { maximum: 8 }

  normalize_attributes :name, :unit_num, :old_id, :old_name

  def full_name
    "#{community.abbrv}: #{name}"
  end

  def over_limit?(community)
    credit_limits.find_by(community: community).try(:exceeded?) || false
  end

  def active?
    true # To be implemented later
  end

  def from_grot?
    old_id.present? || old_name.present?
  end
end
