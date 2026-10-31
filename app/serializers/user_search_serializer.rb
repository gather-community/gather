# frozen_string_literal: true

# Serializes Users for Elasticsearch.
# Only what search matches or shows, so no contact details or allergies get copied into the index.
class UserSearchSerializer < ApplicationSerializer
  attributes :id, :kind, :community_id, :first_name, :last_name

  def kind = "user"

  def community_id = object.household.community_id
end
