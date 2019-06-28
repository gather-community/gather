# frozen_string_literal: true

class AddMealsPrefixToTables < ActiveRecord::Migration[5.1]
  def change
    rename_table :signups, :meal_signups
    rename_table :invitations, :meal_invitations
  end
end
