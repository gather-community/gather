# frozen_string_literal: true

module Work
  # A share describes what portion of the full workload a particular user is responsible for.
  class Share < ApplicationRecord
    acts_as_tenant :cluster

    attr_accessor :rounds_completed, :current_min_need, :num_rounds, :hours_per_round

    belongs_to :period, inverse_of: :shares
    belongs_to :user

    scope :in_community, ->(c) { joins(:period).where(work_periods: {community_id: c.id}) }
    scope :for_period, ->(p) { joins(:user).where(period_id: p.id, users: {deactivated_at: nil}) }
    scope :nonzero, -> { where("portion > 0") }
    scope :by_user_name, -> { joins(:user).merge(User.by_name) }

    delegate :community, to: :period
    delegate :household_id, to: :user
    delegate :zero?, to: :portion

    def adjusted_quota
      period.quota.nil? ? nil : period.quota * portion
    end

    def finished_computing?
      rounds_completed.positive? && current_min_need.abs < 0.001
    end
  end
end
