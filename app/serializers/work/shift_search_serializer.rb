# frozen_string_literal: true

module Work
  # Serializes Shifts for Elasticsearch.
  class ShiftSearchSerializer < ApplicationSerializer
    attributes :id, :job_title, :requester_name, :assignee_names, :community_id, :period_id

    def requester_name
      object.job_requester.try(:name)
    end

    def assignee_names
      object.assignments.flat_map { |a| [a.user.first_name, a.user.last_name] }
    end

    def community_id
      object.job.period.community_id
    end

    def period_id
      object.job.period_id
    end
  end
end
