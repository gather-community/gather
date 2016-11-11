# A group of related communities.
class Cluster < ActiveRecord::Base
  has_many :communities, inverse_of: :cluster
end
