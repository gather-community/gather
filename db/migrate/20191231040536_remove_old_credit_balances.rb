# frozen_string_literal: true

class RemoveOldCreditBalances < ActiveRecord::Migration[6.0]
  def change
    drop_table(:old_credit_balances)
  end
end
