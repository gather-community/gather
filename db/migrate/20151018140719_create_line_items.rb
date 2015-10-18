class CreateLineItems < ActiveRecord::Migration
  def change
    create_table :line_items do |t|
      t.date :incurred_on, null: false
      t.string :code, null: false, limit: 16
      t.string :description, null: false, limit: 255
      t.decimal :amount, null: false, precision: 10, scale: 3
      t.references :household, null: false, foreign_key: true
      t.integer :invoiceable_id
      t.string :invoiceable_type, limit: 32

      t.timestamps null: false
    end
    add_index :line_items, :incurred_on
    add_index :line_items, :code
    add_index :line_items, :household_id
    add_index :line_items, [:invoiceable_id, :invoiceable_type]
  end
end
