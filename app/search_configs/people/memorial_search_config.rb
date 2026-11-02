# frozen_string_literal: true

module People
  # Search config for People::Memorial
  module MemorialSearchConfig
    extend ActiveSupport::Concern

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
          indexes :user_name, analyzer: "english_stemmed"
          indexes :obituary, analyzer: "english_stemmed"
          indexes :messages_body, analyzer: "english_stemmed"
        end
      end

      after_save { __elasticsearch__.index_document }
      after_destroy { __elasticsearch__.delete_document }
    end

    def as_indexed_json(_options = {})
      MemorialSearchSerializer.new(self).as_json
    end
  end
end
