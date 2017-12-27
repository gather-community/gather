class RenameMealsMessagesRecipientsToRecipientType < ActiveRecord::Migration[4.2]
  def change
    rename_column :meals_messages, :recipients, :recipient_type
  end
end
