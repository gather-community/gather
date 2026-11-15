# frozen_string_literal: true

module People
  # Search config for People::Pet
  module PetSearchConfig
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
          indexes :household_id, type: :integer
          indexes :name, analyzer: "english_stemmed"
          indexes :species, analyzer: "english_stemmed"
          indexes :color, analyzer: "english_stemmed"
          indexes :vet, analyzer: "english_stemmed"
          indexes :health_issues, analyzer: "english_stemmed"
          indexes :caregivers, analyzer: "english_stemmed"
        end
      end

      after_save { __elasticsearch__.index_document }
      after_destroy { __elasticsearch__.delete_document }
    end
    # rubocop:enable Metrics/BlockLength

    def as_indexed_json(_options = {})
      PetSearchSerializer.new(self).as_json
    end
  end
end
