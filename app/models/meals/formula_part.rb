# frozen_string_literal: true

module Meals
  # Joins formula to meal part
  class FormulaPart < ApplicationRecord
    acts_as_tenant :cluster
    acts_as_list scope: :formula, column: :rank

    attr_accessor :share_input

    belongs_to :formula, inverse_of: :parts
    belongs_to :type

    scope :by_rank, -> { order(:rank) }

    validates :share_input, presence: true

    before_validation :set_share_from_input

    accepts_nested_attributes_for :type

    delegate :name, to: :type
    delegate :fixed_meal?, to: :formula

    def nonzero?
      !share.zero?
    end

    # 73 TODO: Remove
    def legacy_type
      name.downcase.gsub(" ", "_")
    end

    private

    def set_share_from_input
      self.share = CurrencyPercentageNormalizer.normalize(share_input, pct: !fixed_meal?)
    end
  end
end
