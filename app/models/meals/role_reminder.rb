# frozen_string_literal: true

module Meals
  # Models a reminder for a meal role.
  # Doesn't support absolute times since that wouldn't make sense.
  class RoleReminder < ApplicationRecord
    REL_UNIT_SIGN_OPTIONS = %i[days_before days_after hours_before hours_after].freeze

    belongs_to :role, class_name: "Meals::Role", inverse_of: :reminders

    validates :rel_magnitude, presence: true

    normalize_attributes :note
  end
end
