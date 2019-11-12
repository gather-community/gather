# frozen_string_literal: true

class AddPrivacySettingsToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :privacy_settings, :jsonb, null: false, default: "{}"
  end
end
