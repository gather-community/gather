# frozen_string_literal: true

# Search config for User
module UserSearchConfig
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
        indexes :first_name, analyzer: "english_stemmed"
        indexes :last_name, analyzer: "english_stemmed"
        indexes :email, type: :keyword
        indexes :allergies, analyzer: "english_stemmed"
        indexes :home_phone, type: :keyword
        indexes :mobile_phone, type: :keyword
        indexes :work_phone, type: :keyword
      end
    end

    after_save :update_search_index
    after_destroy do
      __elasticsearch__.delete_document
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      nil
    end

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
    UserSearchSerializer.new(self).as_json
  end
end
