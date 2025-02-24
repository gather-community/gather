# frozen_string_literal: true

module Meals
# == Schema Information
#
# Table name: meal_types
#
#  id             :bigint           not null, primary key
#  category       :string(32)
#  deactivated_at :datetime
#  name           :string(32)       not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  cluster_id     :bigint           not null
#  community_id   :bigint           not null
#
# Indexes
#
#  index_meal_types_on_cluster_id    (cluster_id)
#  index_meal_types_on_community_id  (community_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#
  # Models a type of meal like Adult Veg or Pepperoni slice
  class Type < ApplicationRecord
    include Deactivatable

    NAME_MAX_LENGTH = 32

    acts_as_tenant :cluster

    belongs_to :community

    normalize_attribute :name, :category

    validates :name, presence: true, length: {maximum: NAME_MAX_LENGTH}

    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :by_name, -> { alpha_order(:name) }
    scope :matching, ->(q) { where("name ILIKE ?", "%#{q}%") }
  end
end
