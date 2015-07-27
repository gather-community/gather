class Household < ActiveRecord::Base
  belongs_to :community

  scope :sorted, -> { includes(:community).order('communities.name, households.unit_num') }

  def name
    "#{community.name}: #{unit_num}#{suffix}"
  end
end
