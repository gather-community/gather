class RemoveAccountBalanceFromHouseholds < ActiveRecord::Migration[4.2]
  def change
    remove_column :households, :account_balance, :decimal
  end
end
