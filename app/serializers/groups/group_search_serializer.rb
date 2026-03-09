# frozen_string_literal: true

module Groups
  # Serializes Groups for Elasticsearch.
  class GroupSearchSerializer < ApplicationSerializer
    attributes :id, :kind, :community_ids, :name, :description, :mailman_list_name, :mailman_list_fqdn

    def kind = "group"

    def community_ids = object.communities.pluck(:id)

    def description = object.description.to_s

    def mailman_list_name = object.mailman_list&.name

    def mailman_list_fqdn = object.mailman_list&.fqdn_listname
  end
end
