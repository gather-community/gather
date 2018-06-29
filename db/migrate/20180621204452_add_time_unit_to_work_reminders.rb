class AddTimeUnitToWorkReminders < ActiveRecord::Migration[5.1]
  def change
    add_column :work_reminders, :rel_unit_sign, :string
  end
end
