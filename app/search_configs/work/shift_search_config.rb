# frozen_string_literal: true

module Work
  # Search config for Work::Shift
  module ShiftSearchConfig
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
          indexes :job_title, analyzer: "english_stemmed"
          indexes :requester_name, analyzer: "english_stemmed"
          indexes :assignee_names, analyzer: "english_stemmed"
          indexes :community_id, type: :integer
          indexes :period_id, type: :integer
        end
      end

      # Explicit list of text fields for multi_match queries.
      # Does not include integer filter fields (community_id, period_id).
      def self.indexed_fields
        %i[job_title requester_name assignee_names]
      end
    end

    def as_indexed_json(_options = {})
      # Keys don't get transformed here b/c we're calling as_json on the serializer directly,
      # not the SerializableResource.
      ShiftSearchSerializer.new(self).as_json
    end
  end
end
