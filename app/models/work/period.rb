module Work
  class Period < ApplicationRecord
    PHASE_OPTIONS = %i(draft open published archived)

    acts_as_tenant :cluster

    belongs_to :community

    scope :for_community, ->(c) { where(community_id: c.id) }
    scope :with_phase, ->(p) { where(phase: p) }
    scope :active, -> { where.not(phase: "archived") }
    scope :by_date, -> { order(:starts_on, :ends_on) }
  end
end
