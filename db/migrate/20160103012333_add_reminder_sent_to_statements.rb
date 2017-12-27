class AddReminderSentToStatements < ActiveRecord::Migration[4.2]
  def change
    add_column :statements, :reminder_sent, :boolean, null: false, default: false
  end
end
