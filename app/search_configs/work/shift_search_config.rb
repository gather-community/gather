# frozen_string_literal: true

module Work
  # Search config for Work::Shift
  module ShiftSearchConfig
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
          indexes :job_title, analyzer: "english_stemmed"
          indexes :requester_name, analyzer: "english_stemmed"
          indexes :assignee_names, analyzer: "english_stemmed"
        end
      end
    end

    def as_indexed_json(_options = {})
      ShiftSearchSerializer.new(self)
    end
  end
end
