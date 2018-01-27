module Work
  class Job < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community
    belongs_to :period, class_name: "Work::Period"
    belongs_to :requester, class_name: "People::Group"

    scope :in_community, ->(c) { where(community_id: c.id) }
  end
end
