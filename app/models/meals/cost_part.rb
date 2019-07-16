# frozen_string_literal: true

module Meals
  # Joins a meal cost object to its constituent meal types.
  class CostPart < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :type
    belongs_to :cost, inverse_of: :parts
  end
end
