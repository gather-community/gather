class AddBalanceDueAndCurrentBalanceToAccounts < ActiveRecord::Migration[4.2]
  def change
    add_column :accounts, :balance_due, :decimal, precision: 10, scale: 3, null: false, default: 0
    add_column :accounts, :current_balance, :decimal, precision: 10, scale: 3, null: false, default: 0
  end
end
