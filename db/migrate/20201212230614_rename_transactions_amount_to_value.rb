# frozen_string_literal: true

class RenameTransactionsAmountToValue < ActiveRecord::Migration[6.0]
  def change
    rename_column :transactions, :amount, :value
  end
end
