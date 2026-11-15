# frozen_string_literal: true

class CreateMessagingAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :messaging_accounts do |t|
      t.references :cluster, null: false, foreign_key: true
      t.references :community, null: false, foreign_key: true, index: {unique: true}
      t.string :currency, limit: 3, null: false
      t.timestamps
    end
  end
end
