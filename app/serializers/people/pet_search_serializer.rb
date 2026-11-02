# frozen_string_literal: true

module People
  # Serializes Pets for Elasticsearch.
  class PetSearchSerializer < ApplicationSerializer
    attributes :id, :kind, :community_id, :household_id, :name, :species,
      :color, :vet, :health_issues, :caregivers

    def kind = "pet"

    def community_id = object.household.community_id

    def species = object.species.to_s

    def color = object.color.to_s

    def vet = object.vet.to_s

    def health_issues = object.health_issues.to_s

    def caregivers = object.caregivers.to_s
  end
end
