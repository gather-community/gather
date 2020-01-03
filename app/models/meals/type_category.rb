# frozen_string_literal: true

module Meals
  # Represents a meal type category. Not persisted in separate table.
  class TypeCategory
    include ActiveModel::Model
    include ActiveModel::Serialization

    attr_accessor :name
  end
end
