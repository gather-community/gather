class SetGoogleEmailNullTrue < ActiveRecord::Migration
  def change
    change_column_null :users, :google_email, true
  end
end
