# frozen_string_literal: true

module Meals
  class Type < ApplicationRecord
    acts_as_tenant :cluster
  end
end
