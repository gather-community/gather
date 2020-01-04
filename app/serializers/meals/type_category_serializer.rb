# frozen_string_literal: true

module Meals
  class TypeCategorySerializer < ApplicationSerializer
    attributes :id, :name

    def id
      object.name
    end
  end
end
