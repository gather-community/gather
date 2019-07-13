# frozen_string_literal: true

module Meals
  # Joins formula to meal part
  class FormulaPart < ApplicationRecord
    acts_as_tenant :cluster
    acts_as_list scope: :formula, column: :rank

    attr_reader :share_formatted

    belongs_to :formula, inverse_of: :parts
    belongs_to :type

    scope :by_rank, -> { order(:rank) }

    before_validation :set_share_form_formatted

    validates :share_formatted, presence: true

    accepts_nested_attributes_for :type

    delegate :name, to: :type
    delegate :fixed_meal?, to: :formula

    def nonzero?
      !share.zero?
    end

    def share_formatted=(value)
      # This is a temporary value which guarantees that `share` will be dirty so that the before_validation
      # callback runs. It should never actually get stored.
      self.share = 999_999_999
      @share_formatted = value
    end

    # 73 TODO: Remove
    def legacy_type
      name.downcase.gsub(" ", "_")
    end

    private

    def set_share_form_formatted
      self.share = CurrencyPercentageNormalizer.normalize(@share_formatted, pct: !formula.fixed_meal?)
    end
  end
end
