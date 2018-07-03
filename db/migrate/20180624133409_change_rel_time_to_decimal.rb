# frozen_string_literal: true

# Folks may want to specify partial hours/days.
class ChangeRelTimeToDecimal < ActiveRecord::Migration[5.1]
  def up
    change_column :work_reminders, :rel_time, :decimal, precision: 10, scale: 2
  end
end
