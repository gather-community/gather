module Work
  class Assignment < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :job
    belongs_to :user

    scope :for_community, ->(c) { joins(job: :period).where("work_periods.community_id": c.id) }

    delegate :community, to: :job
  end
end
