# frozen_string_literal: true

# A group of related communities.
class Cluster < ApplicationRecord
  has_many :communities, inverse_of: :cluster, dependent: :destroy
end
