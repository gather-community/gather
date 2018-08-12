# frozen_string_literal: true

module Work
  # Models a single signup for a single shift.
  class Assignment < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :shift, inverse_of: :assignments, counter_cache: true, touch: true
    belongs_to :user

    scope :in_community, ->(c) { joins(shift: {job: :period}).where("work_periods.community_id": c.id) }
    scope :in_period, ->(p) { joins(shift: :job).merge(Job.in_period(p)) }
    scope :fixed_slot, -> { joins(shift: :job).merge(Job.fixed_slot) }
    scope :preassigned, -> { where(preassigned: true) }

    # Can't merge the order by name scope due to an error/bug with ActsAsTenant
    scope :by_user_name, -> { joins(:user).order(User::NAME_ORDER) }

    delegate :job, :community, :period_pre_open?, :fixed_slot?, :full_community?, to: :shift
    delegate :hours, to: :shift, prefix: true

    before_save do
      # Assignments are automatically marked 'preassigned' if the current phase is before the open phase.
      self.preassigned = period_pre_open?
    end
  end
end
