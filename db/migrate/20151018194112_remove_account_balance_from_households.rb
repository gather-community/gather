class RemoveAccountBalanceFromHouseholds < ActiveRecord::Migration
  def change
    remove_column :households, :account_balance, :decimal
  end
end
