module Work
  class Share < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :period, inverse_of: :shares
    belongs_to :user

    scope :for_community, ->(c) { joins(:period).where("work_periods.community_id": c.id) }
    scope :for_period, ->(p) { joins(:user).where(period_id: p.id, "users.deactivated_at": nil) }
    scope :nonzero, -> { where("portion > 0") }
    scope :by_user_name, -> { joins(:user).merge(User.by_name) }

    delegate :community, to: :period
    delegate :household_id, to: :user

    def adjusted_quota
      period.quota.nil? ? nil : period.quota * portion
    end

    def zero?
      portion.zero?
    end
  end
end
