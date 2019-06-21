# frozen_string_literal: true

module Meals
  # Joins formula to meal part
  class FormulaPart < ApplicationRecord
    acts_as_tenant :cluster
    belongs_to :formula
    belongs_to :type
  end
end
