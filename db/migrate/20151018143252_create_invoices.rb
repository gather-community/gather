# frozen_string_literal: true

class CreateInvoices < ActiveRecord::Migration[4.2]
  def change
    create_table :invoices do |t|
      t.date :started_on, null: false
      t.date :ended_on, null: false
      t.date :due_on, null: false
      t.references :household, null: false, foreign_key: true
      t.decimal :prev_balance, null: false, precision: 10, scale: 3
      t.decimal :total_due, null: false, precision: 10, scale: 3

      t.timestamps null: false
    end
    add_index :invoices, :household_id
    add_index :invoices, :started_on
    add_index :invoices, :ended_on
    add_index :invoices, :due_on
  end
end
