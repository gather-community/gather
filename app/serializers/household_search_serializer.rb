# frozen_string_literal: true

# Serializes Households for Elasticsearch.
class HouseholdSearchSerializer < ApplicationSerializer
  attributes :id, :kind, :community_id, :name, :unit_num

  def kind = "household"

  def unit_num = object.unit_num.to_s
end
