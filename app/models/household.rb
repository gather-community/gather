class Household < ActiveRecord::Base
  belongs_to :community
  has_many :credit_limits

  scope :sorted, -> { includes(:community).order('communities.abbrv, households.name') }
  scope :matching, ->(q) { where("households.name ILIKE ?", "%#{q}%") }

  delegate :name, to: :community, prefix: true

  def full_name
    "#{community.abbrv}: #{name}"
  end

  def over_limit?(community)
    credit_limits.find_by(community: community).try(:exceeded?) || false
  end
end
