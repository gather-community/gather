# frozen_string_literal: true

module Groups
  # An affiliation of a group to a community. A join model.
  class Affiliation < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :group, inverse_of: :affiliations
    belongs_to :community
  end
end
