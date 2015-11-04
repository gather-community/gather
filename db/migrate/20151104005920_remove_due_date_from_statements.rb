class RemoveDueDateFromStatements < ActiveRecord::Migration
  def change
    remove_column :statements, :due_on, :date
  end
end
