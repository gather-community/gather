# frozen_string_literal: true

module Meals
  class RoleReminderDecorator < ApplicationDecorator
    delegate_all

    def rel_magnitude_to_i_or_f
      return nil if rel_magnitude.blank?
      to_int_if_no_fractional_part(rel_magnitude)
    end
  end
end
