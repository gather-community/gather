class People::Group < ApplicationRecord
  acts_as_tenant :cluster

  belongs_to :community

  scope :in_community, ->(c) { where(community_id: c.id) }
  scope :by_name, -> { alpha_order(:name) }

  after_update { Work::ShiftIndexUpdater.new(self).update }
end
