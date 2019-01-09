# frozen_string_literal: true

module Work
  # Models an archetype of a job that can be instantiated for a given period.
  # Used heavily in meals-work integration.
  class JobTemplate < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community
    belongs_to :requester, class_name: "People::Group"

    scope :by_title, -> { alpha_order(:title) }
    scope :in_community, ->(c) { where(community_id: c.id) }

    normalize_attributes :title, :description

    before_validation :normalize

    private

    def normalize
      if time_type == "date_time" && meal?
        if shift_start_offset.present? && shift_end_offset.present?
          self.hours = (shift_end_offset - shift_start_offset).to_f / 60
        end
      else
        self.shift_start_offset = nil
        self.shift_end_offset = nil
      end
    end
  end
end
