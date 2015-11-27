class RemoveCreditLimitTable < ActiveRecord::Migration
  def up
    drop_table :credit_limits
  end
end
