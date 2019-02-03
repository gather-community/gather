# frozen_string_literal: true

module Meals
  # Models a reminder for a meal role.
  # Doesn't support absolute times since that wouldn't make sense.
  class RoleReminder < ApplicationRecord
    REL_UNIT_SIGN_OPTIONS = %i[days_before days_after hours_before hours_after].freeze

    acts_as_tenant :cluster

    belongs_to :role, class_name: "Meals::Role", inverse_of: :reminders, foreign_key: :meal_role_id
    has_many :deliveries, class_name: "Meals::ReminderDelivery", foreign_key: :reminder_id,
                          inverse_of: :reminder, dependent: :destroy

    # Used for consistency in display and specs.
    scope :canonical_order, -> { order(:rel_unit_sign, :rel_magnitude, :note) }

    after_create :create_or_update_deliveries

    validates :rel_magnitude, presence: true

    normalize_attributes :note

    def note?
      note.present?
    end

    def abs_time?
      false
    end

    def rel_time?
      true
    end

    def rel_after?
      %w[days_after hours_after].include?(rel_unit_sign)
    end

    def rel_sign
      rel_after? ? 1 : -1
    end

    def rel_days?
      %w[days_before days_after].include?(rel_unit_sign)
    end

    def create_or_update_deliveries
      Meal.where(formula_id: role.formulas.pluck(:id)).pluck(:id).each do |meal_id|
        if (delivery = deliveries.find_by(meal_id: meal_id))
          delivery.save! # Run callbacks to ensure recomputation.
        else
          deliveries.create!(meal_id: meal_id)
        end
      end
    end
  end
end
