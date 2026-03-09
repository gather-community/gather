# frozen_string_literal: true

module Meals
  # Serializes Meals for Elasticsearch.
  class MealSearchSerializer < ApplicationSerializer
    attributes :id, :kind, :community_id, :title, :entrees, :side, :kids,
      :dessert, :notes, :allergens, :served_at

    def kind = "meal"

    def allergens
      return "" unless object.allergens.is_a?(Hash)
      object.allergens.select { |_, v| v }.keys.join(" ")
    end

    def title = object.title.to_s

    def entrees = object.entrees.to_s

    def side = object.side.to_s

    def kids = object.kids.to_s

    def dessert = object.dessert.to_s

    def notes = object.notes.to_s
  end
end
