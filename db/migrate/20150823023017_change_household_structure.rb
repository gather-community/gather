# frozen_string_literal: true

class ChangeHouseholdStructure < ActiveRecord::Migration[4.2]
  NAMES = %w[Buckland Edmunds Payne Rutherford Gibson Brown Rees Walsh Powell].freeze

  def up
    add_column :households, :name, :string, index: true unless column_exists?(:households, :name)
    add_index :households, %i[community_id name], unique: true

    # Add some random names for existing mock households
    Household.where(name: nil).each_with_index { |h, i| h.update_attribute(:name, NAMES[i]) }

    change_column_null :households, :name, false
  end
end
