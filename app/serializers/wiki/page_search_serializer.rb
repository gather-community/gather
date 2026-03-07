# frozen_string_literal: true

module Wiki
  # Serializes Pages for Elasticsearch.
  class PageSearchSerializer < ApplicationSerializer
    attributes :id, :community_id, :title, :content, :slug, :updated_at
  end
end
