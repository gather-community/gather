# frozen_string_literal: true

module Work
# == Schema Information
#
# Table name: work_shares
#
#  id         :bigint           not null, primary key
#  portion    :decimal(4, 3)    default(1.0), not null
#  priority   :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :integer          not null
#  period_id  :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_work_shares_on_period_id              (period_id)
#  index_work_shares_on_period_id_and_user_id  (period_id,user_id) UNIQUE
#  index_work_shares_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (period_id => work_periods.id)
#  fk_rails_...  (user_id => users.id)
#
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
