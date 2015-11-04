class AddDateTimeIndices < ActiveRecord::Migration
  def change
    add_index :statements, :created_at
  end
end
