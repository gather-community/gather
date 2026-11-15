# frozen_string_literal: true

class CreateMessagingTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :messaging_transactions do |t|
      t.references :cluster, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: {to_table: :messaging_accounts}
      t.references :creator, null: true, foreign_key: {to_table: :users}
      t.string :description, limit: 255, null: false
      t.integer :amount_cents, null: false
      t.string :stripe_invoice_line_item_id
      t.timestamps
    end

    add_index :messaging_transactions, :stripe_invoice_line_item_id, unique: true
  end
end
