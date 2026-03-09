# frozen_string_literal: true

# Serializes Users for Elasticsearch.
class UserSearchSerializer < ApplicationSerializer
  attributes :id, :kind, :community_id, :first_name, :last_name, :email,
    :allergies, :home_phone, :mobile_phone, :work_phone

  def kind = "user"

  def community_id = object.household.community_id

  def allergies = object.allergies.to_s
end
