# frozen_string_literal: true

class AddTimeUnitToWorkReminders < ActiveRecord::Migration[5.1]
  def change
    add_column :work_reminders, :time_unit, :string
  end
end
