class RemoveOldCreditLimitCols < ActiveRecord::Migration
  def change
    remove_column :households, :credit_limit
    remove_column :households, :over_limit
  end
end
