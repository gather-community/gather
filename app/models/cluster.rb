# frozen_string_literal: true

# A group of related communities.
class Cluster < ApplicationRecord
  has_many :communities, inverse_of: :cluster, dependent: :destroy

  def self.cluster_based_models
    Rails.application.eager_load! if Rails.env.development?

    # table_exists? required because some fake models shouldn't be included.
    ApplicationRecord.descendants.select { |c| c.table_exists? && c.column_names.include?("cluster_id") }
  end
end
