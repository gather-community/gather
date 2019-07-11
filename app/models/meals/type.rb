# frozen_string_literal: true

module Meals
  # Models a type of meal like Adult Veg or Pepperoni slice
  class Type < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community

    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :by_name, -> { alpha_order(:name) }
    scope :matching, ->(q) { where("name ILIKE ?", "%#{q}%") }
  end
end
