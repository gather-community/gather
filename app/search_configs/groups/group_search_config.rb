# frozen_string_literal: true

module Groups
  # Search config for Groups::Group
  module GroupSearchConfig
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
          indexes :community_ids, type: :integer
          indexes :name, analyzer: "english_stemmed"
          indexes :description, analyzer: "english_stemmed"
          indexes :mailman_list_name, analyzer: "english_stemmed"
          indexes :mailman_list_fqdn, analyzer: "english_stemmed"
        end
      end

      after_save :update_search_index
      after_destroy { __elasticsearch__.delete_document }

      def update_search_index
        if deactivated_at.present?
          begin
            __elasticsearch__.delete_document
          rescue
            nil
          end
        else
          __elasticsearch__.index_document
        end
      end
    end
    # rubocop:enable Metrics/BlockLength

    def as_indexed_json(_options = {})
      GroupSearchSerializer.new(self).as_json
    end
  end
end
