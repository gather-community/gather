class RemoveCreditLimitTable < ActiveRecord::Migration[4.2]
  def up
    drop_table :credit_limits
  end
end
