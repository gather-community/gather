class ChangeRememberTokenNullConstraint < ActiveRecord::Migration
  def change
    change_column_null :users, :remember_token, true
  end
end
