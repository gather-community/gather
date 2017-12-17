# A group of related communities.
class Cluster < ActiveRecord::Base
  has_many :communities, inverse_of: :cluster, dependent: :destroy

  def self.cluster_based_models
    Rails.application.eager_load! if Rails.env.development?
    ActiveRecord::Base.descendants.select { |c| c.column_names.include?("cluster_id") }
  end
end
