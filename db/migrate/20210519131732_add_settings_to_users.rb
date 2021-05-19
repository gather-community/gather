# frozen_string_literal: true

class AddSettingsToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :settings, :jsonb
  end
end
