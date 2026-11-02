# frozen_string_literal: true

module Groups
  # Serializes Groups for Elasticsearch.
  class GroupSearchSerializer < ApplicationSerializer
    attributes :id, :kind, :community_ids, :name, :description

    def kind = "group"

    def community_ids = object.communities.pluck(:id)

    def description = object.description.to_s
  end
end
