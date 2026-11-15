# frozen_string_literal: true

module Wiki
  # Serializes Pages for Elasticsearch.
  class PageSearchSerializer < ApplicationSerializer
    attributes :id, :kind, :community_id, :title, :content, :slug, :updated_at

    def kind = "wiki_page"
  end
end
