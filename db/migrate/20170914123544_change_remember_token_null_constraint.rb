class ChangeRememberTokenNullConstraint < ActiveRecord::Migration[4.2]
  def change
    change_column_null :users, :remember_token, true
  end
end
