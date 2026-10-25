# frozen_string_literal: true

module Work
  # Search config for Work::Shift
  module ShiftSearchConfig
    extend ActiveSupport::Concern

    included do
      include Elasticsearch::Model
      include Elasticsearch::Model::Callbacks

      # The fields are names and titles communities type in any language, so there's no stemming (an English
      # stemmer would mangle French or Swedish words), and accents are folded so "cafe" finds "Café" and
      # "sodergren" finds "Södergren". preserve_original keeps the accented form too, so an exact match
      # still counts. After changing these settings, rebuild the index with `rake search:reindex`.
      settings index: {
        number_of_shards: 1,
        analysis: {
          filter: {
            folding: {type: "asciifolding", preserve_original: true}
          },
          analyzer: {
            folded: {
              tokenizer: "standard",
              filter: %w[lowercase folding]
            }
          }
        }
      } do
        mappings dynamic: "false" do
          indexes :job_title, analyzer: "folded"
          indexes :requester_name, analyzer: "folded"
          indexes :assignee_names, analyzer: "folded"
        end
      end

      def self.indexed_fields
        mappings.to_hash[:properties].keys
      end
    end

    class_methods do
      # Shifts matching every word of `text` across the indexed fields, as the shifts page's search box
      # does. The size is 10k because the result isn't restricted here; the page's other scopes restrict it.
      # TODO: This doesn't scale. The page's other lenses (at least period and community) should become
      # search filters.
      def text_search(text)
        search(
          query: {
            multi_match: {fields: indexed_fields, query: text, type: :cross_fields, operator: :and}
          },
          size: 10_000
        )
      end
    end

    def as_indexed_json(_options = {})
      # Keys don't get transformed here b/c we're calling as_json on the serializer directly,
      # not the SerializableResource.
      ShiftSearchSerializer.new(self).as_json
    end
  end
end
