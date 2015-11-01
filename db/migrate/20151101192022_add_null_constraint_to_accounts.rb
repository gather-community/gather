class AddNullConstraintToAccounts < ActiveRecord::Migration
  def change
    change_column_null :accounts, :community_id, false
  end
end
