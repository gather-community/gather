# frozen_string_literal: true

module People
  # Search config for People::Vehicle
  module VehicleSearchConfig
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
          indexes :household_id, type: :integer
          indexes :make, analyzer: "english_stemmed"
          indexes :model, analyzer: "english_stemmed"
          indexes :color, analyzer: "english_stemmed"
          indexes :plate, type: :keyword
        end
      end

      after_save { __elasticsearch__.index_document }
      after_destroy { __elasticsearch__.delete_document }
    end

    def as_indexed_json(_options = {})
      VehicleSearchSerializer.new(self).as_json
    end
  end
end
