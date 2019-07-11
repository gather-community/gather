# frozen_string_literal: true

module Meals
  class TypeSerializer < ApplicationSerializer
    attributes :id, :name, :subtype
  end
end
