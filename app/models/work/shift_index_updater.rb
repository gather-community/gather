# frozen_string_literal: true

module Work
  # Receives notifications of updates from User, Group, and Job, and updates the shift index.
  class ShiftIndexUpdater
    include Singleton

    attr_accessor :paused
    alias paused? paused

    def create_or_update_work_job_successful(job)
      return if paused?
      reindex(job.shifts.includes(:job, assignments: :user))
    end
    alias create_work_job_successful create_or_update_work_job_successful
    alias update_work_job_successful create_or_update_work_job_successful

    def update_groups_group_successful(group)
      return if paused?
      return unless group.saved_change_to_name?
      jobs = Job.where(requester: group).includes(:requester, shifts: {job: :period, assignments: :user}).by_title
      jobs.each { |j| reindex(j.shifts) }
    end

    def update_user_successful(user)
      return if paused?
      return unless user.saved_change_to_first_name? || user.saved_change_to_last_name?
      assignments = Assignment.where(user: user).includes(shift: {job: [:requester, :period], assignments: :user})
      assignments.each { |a| reindex(a.shift) }
    end

    # Recreates the index with the current settings and indexes every shift in every cluster. Run by
    # `rake search:reindex`, e.g. after the index's analysis settings change. Returns the number indexed.
    def rebuild_index
      Shift.__elasticsearch__.create_index!(force: true)
      ActsAsTenant.without_tenant do
        shifts = Shift.includes(:job, assignments: :user)
        shifts.find_each.count { |shift| shift.__elasticsearch__.index_document }
      end
    end

    def reindex(shifts)
      Array.wrap(shifts).each { |s| s.__elasticsearch__.index_document }
    end
  end
end
