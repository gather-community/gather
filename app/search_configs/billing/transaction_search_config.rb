# frozen_string_literal: true

module Billing
  # Search config for Billing::Transaction
  module TransactionSearchConfig
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
          indexes :account_id, type: :integer
          indexes :statement_id, type: :integer
          indexes :description, analyzer: "english_stemmed"
          indexes :code, type: :keyword
        end
      end

      after_save { __elasticsearch__.index_document }
      after_destroy { __elasticsearch__.delete_document }
    end

    def as_indexed_json(_options = {})
      TransactionSearchSerializer.new(self).as_json
    end
  end
end
