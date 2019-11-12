# frozen_string_literal: true

class AddPrevStmtOnToStatements < ActiveRecord::Migration[4.2]
  def change
    add_column :statements, :prev_stmt_on, :date
  end
end
