module Work
  class Share < ApplicationRecord
    acts_as_tenant(:cluster)

    belongs_to :period
    belongs_to :user

    scope :for_community, ->(c) { joins(:period).where("work_periods.community_id": c.id) }

    delegate :community, to: :period
  end
end
