# frozen_string_literal: true

module People
  # Serializes EmergencyContacts for Elasticsearch.
  class EmergencyContactSearchSerializer < ApplicationSerializer
    attributes :id, :kind, :community_id, :household_id, :name, :relationship

    def kind = "emergency_contact"

    def community_id = object.household&.community_id

    def relationship = object.relationship.to_s
  end
end
