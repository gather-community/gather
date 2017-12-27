class AddNullConstraintToAccounts < ActiveRecord::Migration[4.2]
  def change
    change_column_null :accounts, :community_id, false
  end
end
