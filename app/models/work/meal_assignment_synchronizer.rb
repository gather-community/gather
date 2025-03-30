# frozen_string_literal: true

module Work
  # Keeps meal and work assignments in sync
  class MealAssignmentSynchronizer
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
      sync_meal_to_shift(shift.meal, shift)
    end

    def create_work_assignment_successful(work_asst)
      return if work_asst.syncing?
      return unless meal_shift?(work_asst.shift)
      sync_shift_to_meal(work_asst.shift, work_asst.meal)
    end

    def update_work_assignment_successful(work_asst)
      return if work_asst.syncing?
      return unless meal_shift?(work_asst.shift)
      sync_shift_to_meal(work_asst.shift, work_asst.meal)
    end

    def destroy_work_assignment_successful(work_asst)
      return if work_asst.syncing?
      return unless meal_shift?(work_asst.shift)
      return if destroyed_jobs[work_asst.job_id] || destroyed_shifts[work_asst.shift_id]
      sync_shift_to_meal(work_asst.shift, work_asst.meal)
    end

    def create_meals_assignment_successful(meal_asst)
      return if meal_asst.syncing?
      return unless (shift = shift_for_meal_assignment(meal_asst))
      sync_meal_to_shift(meal_asst.meal, shift)
    end
    alias_method :update_meals_assignment_successful, :create_meals_assignment_successful
    alias_method :destroy_meals_assignment_successful, :create_meals_assignment_successful

    private

    def sync_shift_to_meal(shift, meal)
      source_ids = shift.assignments.reload.map(&:user_id)
      dest_ids = meal.assignments.reload.where(role_id: shift.meal_role_id).map(&:user_id)
      id_diff(source_ids, dest_ids).each do |uid|
        meal.assignments.create!(user_id: uid, role_id: shift.meal_role_id, syncing: true)
      end
      id_diff(dest_ids, source_ids).each do |uid|
        destroy_assignment(meal.assignments.find_by(user_id: uid, role_id: shift.meal_role_id))
      end
    end

    def sync_meal_to_shift(meal, shift)
      source_ids = meal.assignments.where(role_id: shift.meal_role_id).map(&:user_id)
      dest_ids = shift.assignments.map(&:user_id)
      id_diff(source_ids, dest_ids).each do |uid|
        shift.assignments.create!(user_id: uid, syncing: true)
      end
      id_diff(dest_ids, source_ids).each do |uid|
        destroy_assignment(shift.assignments.find_by(user_id: uid))
      end
    end

    def id_diff(source, dest)
      grouped = source.group_by(&:itself)
      dest.each { |uid| grouped[uid]&.pop }
      grouped.values.flatten
    end

    def meal_shift?(shift)
      shift.present? && shift.meal? && shift.meal_role_id.present?
    end

    def shift_for_meal_assignment(meal_asst)
      Work::Shift.joins(:job).find_by(meal_id: meal_asst.meal_id,
        work_jobs: {meal_role_id: meal_asst.role_id})
    end

    def destroy_assignment(assignment)
      assignment.syncing = true
      assignment.destroy
    end

    def destroyed_jobs
      @destroyed_jobs ||= {}
    end

    def destroyed_shifts
      @destroyed_shifts ||= {}
    end
  end
end
