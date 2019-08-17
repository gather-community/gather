# frozen_string_literal: true

class RemoveOldSignupTypeColumns < ActiveRecord::Migration[5.1]
  TYPES = %i[adult_meat adult_veg senior_meat senior_veg teen_meat teen_veg
             big_kid_meat big_kid_veg little_kid_meat little_kid_veg].freeze

  def up
    TYPES.each do |type|
      %i[meal_costs meal_signups meal_formulas].each do |table|
        remove_column table, type
      end
    end
  end
end
