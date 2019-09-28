# frozen_string_literal: true

module Meals
  # Models a type of meal like Adult Veg or Pepperoni slice
  class Type < ApplicationRecord
    include Deactivatable

    acts_as_tenant :cluster

    belongs_to :community

    validates :name, presence: true, length: {maximum: 32}

    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :by_name, -> { alpha_order(:name) }
    scope :matching, ->(q) { where("name ILIKE ?", "%#{q}%") }
  end
end
