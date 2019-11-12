# frozen_string_literal: true

class RenameLineItems < ActiveRecord::Migration[4.2]
  def change
    rename_table :line_items, :transactions
  end
end
