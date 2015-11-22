class RenameLineItems < ActiveRecord::Migration
  def change
    rename_table :line_items, :transactions
  end
end
