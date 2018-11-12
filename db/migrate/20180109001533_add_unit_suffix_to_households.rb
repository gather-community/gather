# frozen_string_literal: true

class AddUnitSuffixToHouseholds < ActiveRecord::Migration[5.1]
  def change
    add_column(:households, :unit_suffix, :string)
  end
end
