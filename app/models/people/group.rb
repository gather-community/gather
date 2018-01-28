class People::Group < ApplicationRecord
  acts_as_tenant :cluster

  belongs_to :community

  scope :for_community, ->(c) { where(community_id: c.id) }
  scope :by_name, -> { order("LOWER(name)") }
end
