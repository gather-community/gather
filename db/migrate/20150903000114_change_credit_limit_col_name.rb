class ChangeCreditLimitColName < ActiveRecord::Migration
  def change
    rename_column :credit_limits, :limit, :amount
  end
end
