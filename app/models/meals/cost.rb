# frozen_string_literal: true

module Meals
  # Saves the calculated cost of a meal for future analysis.
  class Cost < ApplicationRecord
    acts_as_tenant :cluster

    PAYMENT_METHODS = %i[check credit].freeze

    has_many :parts, -> { includes(:type).by_rank },
      class_name: "Meals::CostPart", inverse_of: :cost, dependent: :destroy
    belongs_to :meal, inverse_of: :cost

    validates :ingredient_cost, presence: true, numericality: {greater_than_or_equal_to: 0}
    validates :pantry_cost, presence: true, numericality: {greater_than_or_equal_to: 0}
    validates :payment_method, presence: true

    def total_cost
      ingredient_cost + pantry_cost
    end

    def blank?
      ingredient_cost.blank? && pantry_cost.blank? && payment_method.blank?
    end
  end
end
