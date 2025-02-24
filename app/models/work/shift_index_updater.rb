# frozen_string_literal: true

module Work
  # Receives notifications of updates from User, Group, and Job, and updates the shift index.
  class ShiftIndexUpdater
    include Singleton

    attr_accessor :paused
    alias paused? paused

    def create_or_update_work_job_successful(job)
      return if paused?

      reindex(job.shifts.includes(assignments: :user))
    end
    alias create_work_job_successful create_or_update_work_job_successful
    alias update_work_job_successful create_or_update_work_job_successful

    def update_groups_group_successful(group)
      return if paused?
      return unless group.saved_change_to_name?

      jobs = Job.where(requester: group).includes(:requester, shifts: {assignments: :user}).by_title
      jobs.each { |j| reindex(j.shifts) }
    end

    def update_user_successful(user)
      return if paused?
      return unless user.saved_change_to_first_name? || user.saved_change_to_last_name?

      assignments = Assignment.where(user: user).includes(shift: {job: :requester, assignments: :user})
      assignments.each { |a| reindex(a.shift) }
    end

    def reindex(shifts)
      Array.wrap(shifts).each { |s| s.__elasticsearch__.index_document }
    end
  end
end
