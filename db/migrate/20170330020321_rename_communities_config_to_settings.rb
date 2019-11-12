# frozen_string_literal: true

class RenameCommunitiesConfigToSettings < ActiveRecord::Migration[4.2]
  def change
    rename_column :communities, :config, :settings
  end
end
