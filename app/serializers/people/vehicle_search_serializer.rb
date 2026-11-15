# frozen_string_literal: true

module People
  # Serializes Vehicles for Elasticsearch.
  class VehicleSearchSerializer < ApplicationSerializer
    attributes :id, :kind, :community_id, :household_id, :make, :model, :color, :plate

    def kind = "vehicle"

    def community_id = object.household.community_id

    def make = object.make.to_s

    def model = object.model.to_s

    def color = object.color.to_s

    def plate = object.plate.to_s
  end
end
