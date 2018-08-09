# frozen_string_literal: true

# Whether there is staggering or not.
class AddPickTypeToWorkPeriods < ActiveRecord::Migration[5.1]
  def up
    add_column :work_periods, :pick_type, :string
    execute("UPDATE work_periods SET pick_type = 'free_for_all'")
    change_column_null :work_periods, :pick_type, false
  end

  def down
    remove_column :work_periods, :pick_type
  end
end
