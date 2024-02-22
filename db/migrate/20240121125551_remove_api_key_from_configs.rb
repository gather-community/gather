# frozen_string_literal: true

class RemoveApiKeyFromConfigs < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_configs, :api_key, :string
  end
end
