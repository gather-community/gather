class Household < ActiveRecord::Base
  belongs_to :community
  has_many :credit_limits
  has_many :users

  scope :by_name, -> { order("households.name") }
  scope :by_commty_and_name, -> { includes(:community).order("communities.abbrv, households.name") }
  scope :matching, ->(q) { where("households.name ILIKE ?", "%#{q}%") }

  delegate :name, :abbrv, to: :community, prefix: true

  def full_name
    "#{community.abbrv}: #{name}"
  end

  def over_limit?(community)
    credit_limits.find_by(community: community).try(:exceeded?) || false
  end

  def deleted?
    false # To be implemented later
  end
end
