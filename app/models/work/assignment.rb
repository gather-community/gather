module Work
  class Assignment < ApplicationRecord
    acts_as_tenant :cluster

    # We set touch: true so that assignment changes will update the shift and job updated_at stamp, which
    # we use in a cache key.
    belongs_to :shift, inverse_of: :assignments, touch: true
    belongs_to :user

    scope :for_community, ->(c) { joins(shift: {job: :period}).where("work_periods.community_id": c.id) }

    delegate :community, to: :shift
  end
end
