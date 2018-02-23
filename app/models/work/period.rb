module Work
  class Period < ApplicationRecord
    PHASE_OPTIONS = %i(draft open published archived)

    acts_as_tenant :cluster

    belongs_to :community
    has_many :shares, inverse_of: :period

    scope :for_community, ->(c) { where(community_id: c.id) }
    scope :with_phase, ->(p) { where(phase: p) }
    scope :active, -> { where.not(phase: "archived") }
    scope :latest_first, -> { order(starts_on: :desc, ends_on: :desc) }

    accepts_nested_attributes_for :shares
  end
end
