# frozen_string_literal: true

module Work
  # PORO for cloning work periods
  class PeriodCloner
    include ActiveModel::Model

    JOB_ATTRIBS_TO_COPY = %i[description double_signups_allowed hours hours_per_shift
                             requester_id slot_type time_type title].freeze
    REMINDER_ATTRIBS_TO_COPY = %i[abs_rel note rel_magnitude rel_unit_sign].freeze

    attr_accessor :old_period, :new_period

    # Called when newp is a blank, unpersisted period.
    def copy_attributes_and_shares
      new_period.job_copy_source_id = old_period.id
      %i[meal_job_requester_id pick_type quota_type round_duration
         max_rounds_per_worker workers_per_round].each do |attrib|
        new_period[attrib] = old_period[attrib]
      end

      old_period.shares.includes(:user).find_each do |share|
        next if share.user.inactive?

        new_period.shares.build(period: new_period, user_id: share.user_id, portion: share.portion,
                                priority: share.priority)
      end
    end

    # Called when newp's attributes have been populated by the user, but it is still unpersisted.
    def copy_jobs
      old_period.jobs.each { |j| copy_job(j) }
      # Print some debug info if what we've created has validation errors.
      if new_period.invalid?
        Rails.logger.debug(new_period.errors)
        Rails.logger.debug(new_period.jobs.map { |j| [j.errors] + j.shifts.map(&:errors) })
      end
    end

    private

    def copy_job(old_job)
      # Meal jobs should be imported separately from the meals module.
      return if old_job.meal_role?

      new_job = new_period.jobs.build
      JOB_ATTRIBS_TO_COPY.each { |a| new_job[a] = old_job[a] }
      copy_reminders(old_job, new_job)
      old_job.shifts.each_with_index do |shift, index|
        copy_shift(old_shift: shift, new_job: new_job, is_first: index.zero?)
      end
    end

    def copy_reminders(old_job, new_job)
      old_job.reminders.each do |old_reminder|
        new_reminder = new_job.reminders.build
        REMINDER_ATTRIBS_TO_COPY.each { |a| new_reminder[a] = old_reminder[a] }
        if old_reminder.abs_time?
          period_day_diff = new_period.starts_on - old_period.starts_on
          new_reminder.abs_time = old_reminder.abs_time + period_day_diff.days
        end
      end
    end

    def copy_shift(old_shift:, new_job:, is_first: false)
      new_bounds = new_shift_bounds(old_shift)
      if new_bounds.first.to_date >= new_period.ends_on
        if is_first
          shift_length = ((new_bounds.last - new_bounds.first) / 1.day).ceil
          days_past_period_end = new_bounds.first.to_date - new_period.ends_on
          delta = (shift_length + days_past_period_end - 1).days
          new_bounds = (new_bounds.first - delta)..(new_bounds.last - delta)
        else
          return
        end
      end
      new_shift = new_job.shifts.build(slots: old_shift.slots)
      new_shift.starts_at = new_bounds.first
      new_shift.ends_at = [new_bounds.last, normalize_end_time(new_period.ends_on)].min
      copy_assignments(old_shift: old_shift, new_shift: new_shift)
    end

    def copy_assignments(old_shift:, new_shift:)
      return unless new_period.copy_preassignments?

      old_shift.assignments.preassigned.each do |old_assignment|
        next if old_assignment.user.inactive?

        new_shift.assignments.build(preassigned: true, user_id: old_assignment.user_id)
      end
    end

    def new_shift_bounds(old_shift)
      if old_shift.full_period?
        starts_at = Time.zone.parse(new_period.starts_on.to_fs)
        ends_at = Time.zone.parse(new_period.ends_on.to_fs) + 1.day - 1.minute
      elsif periods_and_shift_have_month_boundaries?(old_shift)
        period_month_diff = ((new_period.starts_on - old_period.starts_on) / 30).round
        starts_at = old_shift.starts_at + period_month_diff.months
        # Sometimes adding months (e.g. to Feb 29) doesn't get you to the end of the future month.
        ends_at = normalize_end_time((old_shift.ends_at + period_month_diff.months).end_of_month)
      else
        period_day_diff = new_period.starts_on - old_period.starts_on
        starts_at = old_shift.starts_at + period_day_diff.days
        ends_at = old_shift.ends_at + period_day_diff.days
      end
      starts_at..ends_at
    end

    def periods_and_shift_have_month_boundaries?(shift)
      return false unless shift.date_only?
      return unless old_period_has_month_boundaries?
      return unless new_period_has_month_boundary_start?

      shift_month_start = shift.starts_at.to_date == shift.starts_at.to_date.beginning_of_month
      shift_month_end = shift.ends_at.to_date == shift.ends_at.to_date.end_of_month
      shift_month_start && shift_month_end
    end

    def old_period_has_month_boundaries?
      return @old_period_has_month_boundaries if defined?(@old_period_has_month_boundaries)

      period_month_start = old_period.starts_on == old_period.starts_on.beginning_of_month
      period_month_end = old_period.ends_on == old_period.ends_on.end_of_month
      @old_period_has_month_boundaries = period_month_start && period_month_end
    end

    def new_period_has_month_boundary_start?
      return @new_period_has_month_boundary_start if defined?(@new_period_has_month_boundary_start)

      period_month_start = new_period.starts_on == new_period.starts_on.beginning_of_month
      @new_period_has_month_boundary_start = period_month_start
    end

    # The system expects 23:59 but end_of_month can give weird fractions of a second.
    # Given a time on the correct day, this will switch it to the right time.
    def normalize_end_time(time)
      time.midnight + 1.day - 1.minute
    end
  end
end
