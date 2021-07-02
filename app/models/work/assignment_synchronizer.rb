# frozen_string_literal: true

module Work
  # Keeps meal and work assignments in sync
  class AssignmentSynchronizer
    include Singleton

    def destroy_work_job_successful(job)
      return unless job.meal_role?
      # Save the IDs of destroyed jobs in a hash so that we can skip
      # sync for these. If a whole job gets destroyed, we don't want to treat it as if
      # those people un-signed-up from the jobs as that would be surprising to the user.
      destroyed_jobs[job.id] = true
    end

    def destroy_work_shift_successful(shift)
      return unless shift.meal?
      # Similar reasoning to the above. The only time a meal shift can get destroyed
      # is if the meal is destroyed.
      destroyed_shifts[shift.id] = true
    end

    # Assumes a newly created work shift has no assignments yet.
    # Copies assignments from meal if they exist.
    def create_work_shift_successful(shift)
      return unless meal_shift?(shift)
      shift.meal.assignments.where(role_id: shift.meal_role_id).find_each do |assign|
        shift.assignments.create!(user_id: assign.user_id, syncing: true)
      end
    end

    def create_work_assignment_successful(work_asst)
      return if work_asst.syncing?
      return unless meal_shift?(work_asst.shift)
      meal = work_asst.meal
      meal.assignments.create!(role_id: work_asst.meal_role_id, user_id: work_asst.user_id, syncing: true)
    end

    def update_work_assignment_successful(work_asst)
      return if work_asst.syncing?
      return unless meal_shift?(work_asst.shift)
      meal = work_asst.meal
      old_user_id = work_asst.user_id_previous_change[0]
      if (meal_asst = meal.assignments.find_by(role_id: work_asst.meal_role_id, user_id: old_user_id))
        meal_asst.update!(user_id: work_asst.user_id, syncing: true)
      else
        meal.assignments.create!(role_id: work_asst.meal_role_id, user_id: work_asst.user_id, syncing: true)
      end
    end

    def destroy_work_assignment_successful(work_asst)
      return if work_asst.syncing?
      return unless meal_shift?(work_asst.shift)
      return if destroyed_jobs[work_asst.job_id] || destroyed_shifts[work_asst.shift_id]
      meal = work_asst.meal
      meal_asst = meal.assignments.find_by(role_id: work_asst.meal_role_id, user_id: work_asst.user_id)
      meal_asst.syncing = true
      meal_asst.destroy
    end

    def create_meals_assignment_successful(meal_asst)
      return if meal_asst.syncing?
      return unless (shift = shift_for_meal_assignment(meal_asst))
      shift.assignments.create!(user_id: meal_asst.user_id, syncing: true)
    end

    def update_meals_assignment_successful(meal_asst)
      return if meal_asst.syncing?
      return unless (shift = shift_for_meal_assignment(meal_asst))
      old_user_id = meal_asst.user_id_previous_change[0]
      if (work_asst = shift.assignments.find_by(user_id: old_user_id))
        work_asst.update!(user_id: meal_asst.user_id, syncing: true)
      else
        shift.assignments.create!(user_id: meal_asst.user_id, syncing: true)
      end
    end

    def destroy_meals_assignment_successful(meal_asst)
      return if meal_asst.syncing?
      return unless (shift = shift_for_meal_assignment(meal_asst))
      work_asst = shift.assignments.find_by(user_id: meal_asst.user_id)
      work_asst.syncing = true
      work_asst.destroy
    end

    private

    def meal_shift?(shift)
      shift.meal? && shift.meal_role_id.present?
    end

    def shift_for_meal_assignment(meal_asst)
      Work::Shift.joins(:job).find_by(meal_id: meal_asst.meal_id,
                                      work_jobs: {meal_role_id: meal_asst.role_id})
    end

    def destroyed_jobs
      @destroyed_jobs ||= {}
    end

    def destroyed_shifts
      @destroyed_shifts ||= {}
    end
  end
end
