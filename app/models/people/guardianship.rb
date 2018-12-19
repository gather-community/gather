# frozen_string_literal: true

module People
  # Join model between children and parents/guardians.
  class Guardianship < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :guardian, class_name: "User"
    belongs_to :child, class_name: "User"

    scope :related_to, ->(user) { where(guardian: user).or(where(child: user)) }
  end
end
