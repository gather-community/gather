# frozen_string_literal: true

module Meals
# == Schema Information
#
# Table name: meal_formula_parts
#
#  id           :bigint           not null, primary key
#  portion_size :decimal(10, 2)   not null
#  rank         :integer          not null
#  share        :decimal(10, 4)   not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cluster_id   :bigint           not null
#  formula_id   :bigint           not null
#  type_id      :bigint           not null
#
# Indexes
#
#  index_meal_formula_parts_on_cluster_id              (cluster_id)
#  index_meal_formula_parts_on_formula_id              (formula_id)
#  index_meal_formula_parts_on_formula_id_and_type_id  (formula_id,type_id) UNIQUE
#  index_meal_formula_parts_on_type_id                 (type_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (formula_id => meal_formulas.id)
#  fk_rails_...  (type_id => meal_types.id)
#
  # Joins formula to meal part
  class FormulaPart < ApplicationRecord
    acts_as_tenant :cluster
    acts_as_list scope: :formula, column: :rank, top_of_list: 0

    attr_reader :share_formatted

    belongs_to :formula, inverse_of: :parts
    belongs_to :type

    scope :by_rank, -> { order(:rank) }

    before_validation :set_share_form_formatted

    validates :share_formatted, presence: true
    validates :portion_size, presence: true
    validate :appropriate_share_value

    accepts_nested_attributes_for :type

    delegate :name, :category, to: :type
    delegate :fixed_meal?, to: :formula

    def nonzero?
      !share&.zero?
    end

    def share_formatted=(value)
      # This is a temporary value which guarantees that `share` will be dirty so that the before_validation
      # callback runs. It should never actually get stored.
      self.share = 999_999_999
      @share_formatted = value
    end

    private

    def set_share_form_formatted
      self.share = CurrencyPercentageNormalizer.normalize(@share_formatted, pct: !formula.fixed_meal?)
    end

    def appropriate_share_value
      if share.blank? && share_formatted.present?
        errors.add(:share_formatted, :invalid)
      elsif share&.negative?
        errors.add(:share_formatted, :negative)
      end
    end
  end
end
