# frozen_string_literal: true

module People
  # Search config for People::EmergencyContact
  module EmergencyContactSearchConfig
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
          indexes :name, analyzer: "english_stemmed"
          indexes :relationship, analyzer: "english_stemmed"
          indexes :email, type: :keyword
        end
      end

      after_save { __elasticsearch__.index_document }
      after_destroy { __elasticsearch__.delete_document }
    end

    def as_indexed_json(_options = {})
      EmergencyContactSearchSerializer.new(self).as_json
    end
  end
end
