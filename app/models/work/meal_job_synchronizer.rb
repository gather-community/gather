# frozen_string_literal: true

module Work
  # Keeps meals in sync with jobs/shifts
  class MealJobSynchronizer
    include Singleton

    DEFAULT_SHIFT_START_OFFSET = -90
    DEFAULT_SHIFT_END_OFFSET = 0
    DEFAULT_WORK_HOURS = 1.5

    def create_work_period_successful(period)
      sync_jobs_and_shifts(period)
    end

    def update_work_period_successful(period)
      # If dates changed or settings added, changed, or deleted
      if (period.previous_changes.keys & %w[starts_on ends_on meal_job_requester_id]).any? ||
          period.meal_job_sync_settings.any? { |s| s.previous_changes.any? } ||
          (period.previous_meal_job_sync_setting_ids - period.meal_job_sync_settings.map(&:id)).any?
        sync_jobs_and_shifts(period)
      end
    end

    def create_meals_meal_successful(meal)
      sync_jobs_and_shifts_for_periods(meal_periods(meal))
    end

    def update_meals_meal_successful(meal)
      return unless (meal.previous_changes.keys & %w[served_at formula_id]).any?

      periods = meal_periods(meal)
      if meal.served_at_previously_changed?
        old_date = meal.served_at_previous_change[0].to_date
        periods.concat(base_period_scope(meal.community_id).containing_date(old_date).to_a)
        periods.uniq!
      end
      sync_jobs_and_shifts_for_periods(periods)
    end

    def destroy_meals_meal_successful(meal)
      sync_jobs_and_shifts_for_periods(meal_periods(meal))
    end

    def update_meals_role_successful(role)
      period_ids = Work::MealJobSyncSetting.where(role: role).pluck(:period_id)
      periods = Period.with_phase("draft").where(id: period_ids)
      sync_jobs_and_shifts_for_periods(periods)
    end

    private

    def sync_jobs_and_shifts_for_periods(periods)
      periods.each { |p| sync_jobs_and_shifts(p) }
    end

    def base_period_scope(community_id)
      Work::Period.active.in_community(community_id)
    end

    def meal_periods(meal)
      base_period_scope(meal.community_id).containing_date(meal.served_at.to_date).to_a
    end

    def sync_jobs_and_shifts(period)
      ShiftIndexUpdater.instance.paused = true
      job_ids = []
      shift_ids = []
      Meals::Meal.where(served_at: meal_time_range(period)).oldest_first.each do |meal|
        meal.roles.each do |role|
          next unless period_sync_role?(period, meal, role)

          job = find_or_create_job(period, role)
          job_ids << job.id
          shift = find_or_create_shift(job, role, meal)
          shift_ids << shift.id
        end
      end
      Work::Job.where(period_id: period.id).where.not(meal_role: nil).where.not(id: job_ids).destroy_all
      Work::Shift.where(job_id: job_ids).where.not(id: shift_ids).destroy_all
      ShiftIndexUpdater.instance.reindex(Work::Shift.joins(:job).where(work_jobs: {period_id: period.id}))
    ensure
      ShiftIndexUpdater.instance.paused = false
    end

    def meal_time_range(period)
      period.starts_on.midnight...((period.ends_on + 1.day).midnight)
    end

    def period_sync_role?(period, meal, role)
      period.meal_job_sync_settings.exists?(role_id: role.id, formula_id: meal.formula_id)
    end

    def find_or_create_job(period, role)
      job = Work::Job.find_or_initialize_by(period: period, meal_role: role)
      job.title = role.work_job_title || role.title
      job.description = role.description
      job.double_signups_allowed = role.double_signups_allowed
      job.hours = role.work_hours || DEFAULT_WORK_HOURS
      job.requester_id = period.meal_job_requester_id
      job.slot_type = "fixed"
      job.time_type = role.time_type
      fix_title_collisions(job)
      job.save!
      job
    end

    def fix_title_collisions(job)
      original = job.title
      counter = 2
      while job.invalid? && job.errors[:title].include?(I18n.t("errors.messages.taken"))
        job.title = "#{original} #{counter}"
        counter += 1
      end
    end

    def find_or_create_shift(job, role, meal)
      shift = job.shifts.find_or_initialize_by(meal: meal)
      shift.starts_at = meal.served_at + (role.shift_start || DEFAULT_SHIFT_START_OFFSET).minutes
      shift.ends_at = meal.served_at + (role.shift_end || DEFAULT_SHIFT_END_OFFSET).minutes
      shift.slots = role.count_per_meal
      shift.save!
      shift
    end
  end
end
