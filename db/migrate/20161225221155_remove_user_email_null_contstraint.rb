class RemoveUserEmailNullContstraint < ActiveRecord::Migration[4.2]
  def change
    change_column_null :users, :email, true
  end
end
