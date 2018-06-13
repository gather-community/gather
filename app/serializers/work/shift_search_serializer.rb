# frozen_string_literal: true

module Work
  # Serializes Shifts for Elasticsearch.
  class ShiftSearchSerializer < ApplicationSerializer
    attributes :id, :job_title, :requester_name, :assignee_names

    def requester_name
      object.job_requester.try(:name)
    end

    def assignee_names
      object.assignments.flat_map { |a| [a.user.first_name, a.user.last_name] }
    end
  end
end
