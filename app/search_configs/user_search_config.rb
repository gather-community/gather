# frozen_string_literal: true

# Search config for User
module UserSearchConfig
  extend ActiveSupport::Concern

  # rubocop:disable Metrics/BlockLength
  included do
    include Elasticsearch::Model

    settings index: {
      number_of_shards: 1,
      analysis: {
        analyzer: {
          english_stemmed: {
            tokenizer: "standard",
            filter: %w[lowercase porter_stem]
          }
        }
      }
    } do
      mappings dynamic: "false" do
        indexes :kind, type: :keyword
        indexes :community_id, type: :integer
        indexes :first_name, analyzer: "english_stemmed"
        indexes :last_name, analyzer: "english_stemmed"
      end
    end

    after_save :update_search_index
    include SearchDocumentRemoval

    def update_search_index
      if deactivated_at.present?
        remove_search_document
      else
        __elasticsearch__.index_document
      end
    end
  end
  # rubocop:enable Metrics/BlockLength

  def as_indexed_json(_options = {})
    UserSearchSerializer.new(self).as_json
  end
end
