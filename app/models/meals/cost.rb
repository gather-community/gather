# frozen_string_literal: true

module Meals
  # Saves the calculated cost of a meal for future analysis.
  class Cost < ApplicationRecord
    acts_as_tenant :cluster

    PAYMENT_METHODS = %i[check paypal credit].freeze

    has_many :parts, -> { includes(:type).by_rank },
             class_name: "Meals::CostPart", inverse_of: :cost, dependent: :destroy
    belongs_to :meal, class_name: "Meals::Meal", inverse_of: :cost
    belongs_to :reimbursee, class_name: "User", inverse_of: :meal_costs

    validates :ingredient_cost, presence: true, numericality: {greater_than_or_equal_to: 0}
    validates :pantry_cost, presence: true, numericality: {greater_than_or_equal_to: 0}
    validates :payment_method, presence: true
    validates :reimbursee_id, presence: true

    def total_cost
      ingredient_cost + pantry_cost
    end

    def blank?
      ingredient_cost.blank? && pantry_cost.blank? && payment_method.blank?
    end

    def parts_by_type
      @parts_by_type ||= parts.index_by(&:type)
    end
  end
end
