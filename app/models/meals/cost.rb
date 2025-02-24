# frozen_string_literal: true

module Meals
# == Schema Information
#
# Table name: meal_costs
#
#  id               :integer          not null, primary key
#  ingredient_cost  :decimal(10, 2)   not null
#  meal_calc_type   :string
#  pantry_calc_type :string
#  pantry_cost      :decimal(10, 2)   not null
#  pantry_fee       :decimal(10, 2)
#  payment_method   :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  cluster_id       :integer          not null
#  meal_id          :integer          not null
#  reimbursee_id    :bigint
#
# Indexes
#
#  index_meal_costs_on_cluster_id     (cluster_id)
#  index_meal_costs_on_meal_id        (meal_id)
#  index_meal_costs_on_reimbursee_id  (reimbursee_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (meal_id => meals.id)
#  fk_rails_...  (reimbursee_id => users.id)
#
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
