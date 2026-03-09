# frozen_string_literal: true

module Wiki
  # Search config for Wiki::Page
  module PageSearchConfig
    extend ActiveSupport::Concern

    included do
      include Elasticsearch::Model
      include Elasticsearch::Model::Callbacks

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
          indexes :title, analyzer: "english_stemmed"
          indexes :content, analyzer: "english_stemmed"
          indexes :community_id, type: :integer
          indexes :slug, type: :keyword
          indexes :updated_at, type: :date
        end
      end

      def self.indexed_fields
        %i[title content]
      end
    end

    def as_indexed_json(_options = {})
      PageSearchSerializer.new(self).as_json
    end
  end
end
