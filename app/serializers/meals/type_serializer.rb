# frozen_string_literal: true

module Meals
  class TypeSerializer < ApplicationSerializer
    attributes :id, :name, :category
  end
end
