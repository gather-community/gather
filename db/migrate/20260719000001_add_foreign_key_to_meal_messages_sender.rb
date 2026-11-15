class AddForeignKeyToMealMessagesSender < ActiveRecord::Migration[8.1]
  # meal_messages.sender_id has always been NOT NULL but carried no foreign key, so a user
  # deletion could leave rows pointing at a dead id. Meals::Message#sender then read back nil
  # and sender_name raised. People::UserDeletion now reassigns senders to the community's
  # "Deleted Member" placeholder; this constraint makes a future miss fail loudly at deletion
  # time instead of silently corrupting the row.
  #
  # A handful of rows predating the fix already dangle (3 in production, most recent 2024).
  # They are unrecoverable — the sender is gone and there is no record of who it was — so we
  # delete them rather than repoint them at a placeholder that would misattribute the message.
  def up
    orphaned = execute(<<~SQL.squish).cmd_tuples
      DELETE FROM meal_messages
      WHERE sender_id NOT IN (SELECT id FROM users)
    SQL
    say("Deleted #{orphaned} meal_messages with a dangling sender_id")

    add_foreign_key :meal_messages, :users, column: :sender_id
  end

  def down
    remove_foreign_key :meal_messages, column: :sender_id
  end
end
