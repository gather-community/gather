# frozen_string_literal: true

module People
  # Serializes Memorials for Elasticsearch.
  class MemorialSearchSerializer < ApplicationSerializer
    attributes :id, :kind, :community_id, :user_name, :obituary, :messages_body

    def kind = "memorial"

    def community_id = object.user.household.community_id

    def user_name = "#{object.user.first_name} #{object.user.last_name}"

    def obituary = object.obituary.to_s

    def messages_body = object.messages.map(&:body).join(" ")
  end
end
