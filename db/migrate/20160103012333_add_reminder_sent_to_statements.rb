class AddReminderSentToStatements < ActiveRecord::Migration
  def change
    add_column :statements, :reminder_sent, :boolean, null: false, default: false
  end
end
