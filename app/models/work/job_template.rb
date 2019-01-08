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
  end
end
