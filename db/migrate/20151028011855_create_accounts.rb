class CreateAccounts < ActiveRecord::Migration[4.2]
  def change
    create_table :accounts do |t|
      t.references :household, null: false, foreign_key: true, index: true
      t.date :last_invoiced_on
      t.decimal :due_last_invoice, precision: 10, scale: 2
      t.decimal :total_new_credits, null: false, default: 0, precision: 10, scale: 2
      t.decimal :total_new_charges, null: false, default: 0, precision: 10, scale: 2

      t.timestamps null: false
    end
  end
end
