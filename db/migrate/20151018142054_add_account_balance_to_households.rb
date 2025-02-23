# frozen_string_literal: true

class AddAccountBalanceToHouseholds < ActiveRecord::Migration[4.2]
  def change
    add_column :households, :account_balance, :decimal, precision: 10, scale: 3, null: false, default: 0,
                                                        index: true
  end
end
