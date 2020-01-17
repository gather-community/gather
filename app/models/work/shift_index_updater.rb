# frozen_string_literal: true

module Work
  # Receives notifications of updates from User, Group, and Job, and updates the shift index by
  # `touch`ing the affected shifts.
  class ShiftIndexUpdater
    include Singleton

    def create_or_update_work_job_successful(job)
      reindex(job.shifts.includes(assignments: :user))
    end
    alias create_work_job_successful create_or_update_work_job_successful
    alias update_work_job_successful create_or_update_work_job_successful

    def update_groups_group_successful(group)
      return unless group.saved_change_to_name?
      jobs = Job.where(requester: group).includes(:requester, shifts: {assignments: :user}).by_title
      jobs.each { |j| reindex(j.shifts) }
    end

    def update_user_successful(user)
      return unless user.saved_change_to_first_name? || user.saved_change_to_last_name?
      assignments = Assignment.where(user: user).includes(shift: {job: :requester, assignments: :user})
      assignments.each { |a| reindex(a.shift) }
    end

    private

    def reindex(shifts)
      Array.wrap(shifts).each { |s| s.__elasticsearch__.index_document }
    end
  end
end
