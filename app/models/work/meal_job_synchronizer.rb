# frozen_string_literal: true

module Work
  # Keeps meals in sync with jobs/shifts
  class MealJobSynchronizer
    include Singleton

    DEFAULT_SHIFT_START_OFFSET = -90
    DEFAULT_SHIFT_END_OFFSET = 0
    DEFAULT_WORK_HOURS = 1.5

    def create_work_period_successful(period)
      Meals::Meal.where(served_at: meal_time_range(period)).oldest_first.each do |meal|
        meal.roles.each do |role|
          next unless period_sync_role?(period, meal, role)
          job = find_or_create_job(period, role)
          find_or_create_shift(period, job, role, meal)
        end
      end
    end

    private

    def meal_time_range(period)
      period.starts_on.midnight...((period.ends_on + 1.day).midnight)
    end

    def period_sync_role?(period, meal, role)
      period.meal_job_sync_settings.where(role_id: role.id, formula_id: meal.formula_id).exists?
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
      job.save!
      job
    end

    def find_or_create_shift(period, job, role, meal)
      shift = job.shifts.find_or_initialize_by(meal: meal)
      shift.starts_at = meal.served_at + (role.shift_start || DEFAULT_SHIFT_START_OFFSET).minutes
      shift.ends_at = meal.served_at + (role.shift_end || DEFAULT_SHIFT_END_OFFSET).minutes
      shift.slots = role.count_per_meal
      shift.save!
    end
  end
end
