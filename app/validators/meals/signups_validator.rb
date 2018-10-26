# frozen_string_literal: true

module Meals
  # Validates the signups collection on a meal.
  class SignupsValidator < ActiveModel::Validator
    def validate(meal)
      no_duplicate_households(meal)
    end

    private

    def no_duplicate_households(meal)
      signups = meal.signups.to_a
      duplicates = signups - signups.uniq(&:household_id)
      return unless duplicates.any?

      meal.errors.add(:signups, :invalid)
      duplicates.each { |d| d.errors.add(:household_id, :taken) }
    end
  end
end
