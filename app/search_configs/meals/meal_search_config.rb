# frozen_string_literal: true

module Meals
  # Search config for Meals::Meal
  module MealSearchConfig
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
          indexes :title, analyzer: "english_stemmed"
          indexes :entrees, analyzer: "english_stemmed"
          indexes :side, analyzer: "english_stemmed"
          indexes :kids, analyzer: "english_stemmed"
          indexes :dessert, analyzer: "english_stemmed"
          indexes :notes, analyzer: "english_stemmed"
          indexes :allergens, analyzer: "english_stemmed"
          indexes :served_at, type: :date
        end
      end

      after_save { __elasticsearch__.index_document }
      after_destroy { __elasticsearch__.delete_document }
    end
    # rubocop:enable Metrics/BlockLength

    def as_indexed_json(_options = {})
      MealSearchSerializer.new(self).as_json
    end
  end
end
