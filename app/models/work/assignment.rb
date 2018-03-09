# frozen_string_literal: true

module Work
  # Models a single signup for a single shift.
  class Assignment < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :shift, inverse_of: :assignments, counter_cache: true
    belongs_to :user

    scope :for_community, ->(c) { joins(shift: {job: :period}).where("work_periods.community_id": c.id) }

    delegate :community, to: :shift
  end
end
