# frozen_string_literal: true

class AddDueOnToStatements < ActiveRecord::Migration[4.2]
  def change
    add_column :statements, :due_on, :date
    add_index :statements, :due_on
  end
end
