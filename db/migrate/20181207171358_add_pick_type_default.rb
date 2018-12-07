# frozen_string_literal: true

# Helps for now while form doesn't have these fields, fine to keep it after then too.
class AddPickTypeDefault < ActiveRecord::Migration[5.1]
  def up
    change_column_default(:work_periods, :pick_type, "free_for_all")
  end
end
