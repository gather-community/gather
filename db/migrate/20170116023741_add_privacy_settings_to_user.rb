class AddPrivacySettingsToUser < ActiveRecord::Migration
  def change
    add_column :users, :privacy_settings, :jsonb, null: false, default: '{}'
  end
end
