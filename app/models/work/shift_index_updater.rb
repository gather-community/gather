# frozen_string_literal: true

module Work
  # Receives notifications of updates from User, Group, and Job, and updates the shift index by
  # `touch`ing the affected shifts.
  class ShiftIndexUpdater
    attr_accessor :source

    def initialize(source)
      self.source = source
    end

    def update
      send(:"process_#{source.model_name.param_key}")
    end

    private

    def process_work_job
      reindex(source.shifts.includes(assignments: :user))
    end

    def process_people_group
      return unless source.saved_change_to_name?
      jobs = Job.where(requester: source).includes(:requester, shifts: {assignments: :user})
      jobs.each { |j| reindex(j.shifts) }
    end

    def process_user
      return unless source.saved_change_to_first_name? || source.saved_change_to_last_name?
      assignments = Assignment.where(user: source).includes(shift: {job: :requester, assignments: :user})
      assignments.each { |a| reindex(a.shift) }
    end

    def reindex(shifts)
      Array.wrap(shifts).each { |s| s.__elasticsearch__.index_document }
    end
  end
end
