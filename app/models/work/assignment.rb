# frozen_string_literal: true

# == Schema Information
#
# Table name: work_assignments
#
#  id          :bigint           not null, primary key
#  cluster_id  :integer          not null
#  created_at  :datetime         not null
#  preassigned :boolean          default(FALSE), not null
#  shift_id    :integer          not null
#  updated_at  :datetime         not null
#  user_id     :integer          not null
#
module Work
  # Models a single signup for a single shift.
  class Assignment < ApplicationRecord
    include Wisper.model

    acts_as_tenant :cluster

    attr_accessor :syncing
    alias syncing? syncing

    belongs_to :shift, inverse_of: :assignments, counter_cache: true, touch: true
    belongs_to :user

    scope :in_community, ->(c) { joins(shift: {job: :period}).where(work_periods: {community_id: c.id}) }
    scope :in_period, ->(p) { joins(shift: :job).merge(Job.in_period(p)) }
    scope :fixed_slot, -> { joins(shift: :job).merge(Job.fixed_slot) }
    scope :preassigned, -> { where(preassigned: true) }

    # Can't merge the order by name scope due to an error/bug with ActsAsTenant
    scope :by_user_name, -> { joins(:user).alpha_order("users.first_name").alpha_order("users.last_name") }

    delegate :job, :job_id, :community, :period_pre_open?, :fixed_slot?, :full_community?,
             :date_time?, :elapsed_time, :starts_at, :ends_at, :job_title, :job_description,
             :meal, :meal_role_id, to: :shift
    delegate :hours, to: :shift, prefix: true

    before_save do
      # Assignments are automatically marked 'preassigned' if the current phase is before the open phase.
      self.preassigned = period_pre_open?
    end

    def linkable
      shift
    end
  end
end
