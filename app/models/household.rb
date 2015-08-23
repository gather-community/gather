class Household < ActiveRecord::Base
  belongs_to :community

  scope :sorted, -> { includes(:community).order('communities.abbrv, households.name') }

  delegate :name, to: :community, prefix: true

  def full_name
    "#{community.abbrv}: #{name}"
  end
end
