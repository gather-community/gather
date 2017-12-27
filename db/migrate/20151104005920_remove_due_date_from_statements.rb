class RemoveDueDateFromStatements < ActiveRecord::Migration[4.2]
  def change
    remove_column :statements, :due_on, :date
  end
end
