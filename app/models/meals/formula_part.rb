# frozen_string_literal: true

module Meals
  # Joins formula to meal part
  class FormulaPart < ApplicationRecord
    acts_as_tenant :cluster
    belongs_to :formula
    belongs_to :type

    scope :by_rank, -> { order(:rank) }

    validates :share, presence: true, numericality: {greater_than_or_equal_to: 0}

    delegate :name, to: :type
    delegate :fixed_meal?, to: :formula

    def nonzero?
      !share.zero?
    end

    # 73 TODO: Remove
    def legacy_type
      name.downcase.gsub(" ", "_")
    end
  end
end
