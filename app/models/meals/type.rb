# frozen_string_literal: true

module Meals
  # Models a type of meal like Adult Veg or Pepperoni slice
  class Type < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community
  end
end
