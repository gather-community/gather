class SetUsersSettingsNullFalse < ActiveRecord::Migration[6.0]
  def up
    execute("UPDATE users SET settings = '{}' WHERE settings IS NULL")
    change_column_default(:users, :settings, {})
    change_column_null(:users, :settings, false)
  end
end
