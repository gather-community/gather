# frozen_string_literal: true

module Calendars
  # Search config for Calendars::Event
  module EventSearchConfig
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
          indexes :calendar_id, type: :integer
          indexes :name, analyzer: "english_stemmed"
          indexes :note, analyzer: "english_stemmed"
          indexes :location, analyzer: "english_stemmed"
          indexes :starts_at, type: :date
        end
      end

      after_save { __elasticsearch__.index_document }
      after_destroy { __elasticsearch__.delete_document }
    end

    def as_indexed_json(_options = {})
      EventSearchSerializer.new(self).as_json
    end
  end
end
