# frozen_string_literal: true

module Work
  # PORO for cloning work periods
  class PeriodCloner
    include ActiveModel::Model

    JOB_ATTRIBS_TO_COPY = %i[description double_signups_allowed hours hours_per_shift
                             requester_id slot_type time_type title].freeze

    attr_accessor :old_period, :new_period

    # Called when newp is a blank, unpersisted period.
    def copy_attributes_and_shares
      %i[pick_type quota_type round_duration max_rounds_per_worker workers_per_round].each do |attrib|
        new_period[attrib] = old_period[attrib]
      end

      old_period.shares.includes(:user).each do |share|
        next if share.user.inactive?
        new_period.shares.build(period: new_period, user_id: share.user_id, portion: share.portion,
                                priority: share.priority)
      end
    end

    # Called when newp's attributes have been populated by the user, but it is still unpersisted.
    def copy_jobs
      old_period.jobs.each { |j| copy_job(j) }
    end

    private

    def copy_job(old_job)
      # Meal jobs should be imported separately from the meals module.
      return if old_job.meal_role?
      new_job = new_period.jobs.build
      JOB_ATTRIBS_TO_COPY.each { |a| new_job[a] = old_job[a] }
      old_job.shifts.each { |s| copy_shift(old_shift: s, new_job: new_job) }
    end

    def copy_shift(old_shift:, new_job:)
      new_bounds = new_shift_bounds(old_shift)
      return if new_bounds.first.to_date >= new_period.ends_on
      new_shift = new_job.shifts.build(slots: old_shift.slots)
      new_shift.starts_at = new_bounds.first
      new_shift.ends_at = [new_bounds.last, new_period.ends_on.midnight + 1.day - 1.minute].min
    end

    def new_shift_bounds(old_shift)
      if old_shift.full_period?
        starts_at = Time.zone.parse(new_period.starts_on.to_s)
        ends_at = Time.zone.parse(new_period.ends_on.to_s) + 1.day - 1.minute
      elsif month_boundary_period_and_shift?(old_shift)
        period_month_diff = ((new_period.starts_on - old_period.starts_on) / 30).round
        starts_at = old_shift.starts_at + period_month_diff.months
        ends_at = old_shift.ends_at + period_month_diff.months
      else
        period_day_diff = new_period.starts_on - old_period.starts_on
        starts_at = old_shift.starts_at + period_day_diff.days
        ends_at = old_shift.ends_at + period_day_diff.days
      end
      starts_at..ends_at
    end

    def month_boundary_period_and_shift?(shift)
      return false unless shift.date_only?
      shift_month_start = shift.starts_at.to_date == shift.starts_at.to_date.beginning_of_month
      shift_month_end = shift.ends_at.to_date == shift.ends_at.to_date.end_of_month
      period_month_start = old_period.starts_on == old_period.starts_on.beginning_of_month
      period_month_end = old_period.ends_on == old_period.ends_on.end_of_month
      shift_month_start && shift_month_end && period_month_start && period_month_end
    end
  end
end
