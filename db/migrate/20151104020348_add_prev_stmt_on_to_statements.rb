class AddPrevStmtOnToStatements < ActiveRecord::Migration
  def change
    add_column :statements, :prev_stmt_on, :date
  end
end
