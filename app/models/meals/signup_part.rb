# frozen_string_literal: true

module Meals
  # Joins a meal signup object to its constituent meal types.
  class SignupPart < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :type
    belongs_to :signup, inverse_of: :parts

    delegate :zero?, to: :count
  end
end
