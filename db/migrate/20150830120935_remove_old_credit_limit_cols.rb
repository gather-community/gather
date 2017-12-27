class RemoveOldCreditLimitCols < ActiveRecord::Migration[4.2]
  def change
    remove_column :households, :credit_limit
    remove_column :households, :over_limit
  end
end
