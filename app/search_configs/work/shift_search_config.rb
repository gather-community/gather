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
          indexes :community_id, type: :integer
          indexes :period_id, type: :integer
        end
      end
    end

    class_methods do
      # Explicit list of text fields for multi_match queries.
      # Does not include integer filter fields (community_id, period_id).
      def indexed_fields
        %i[job_title requester_name assignee_names]
      end

      # Shifts in the community (and period, if given) where each word of `text` starts a word in one of
      # the indexed fields, as the shifts page's search box does. So "ma" matches Max but "ax" doesn't,
      # the same as the people search (User.matching). Hyphens count as word breaks. The size is 10k
      # because the page's other scopes restrict the result further.
      def text_search(text, community_id:, period_id: nil)
        filters = [{term: {community_id: community_id}}]
        filters << {term: {period_id: period_id}} if period_id
        must = text.to_s.tr("-", " ").split.map do |word|
          {multi_match: {fields: indexed_fields, query: word, type: :phrase_prefix}}
        end
        search(query: {bool: {must: must, filter: filters}}, size: 10_000)
      end
    end

    def as_indexed_json(_options = {})
      # Keys don't get transformed here b/c we're calling as_json on the serializer directly,
      # not the SerializableResource.
      ShiftSearchSerializer.new(self).as_json
    end
  end
end
