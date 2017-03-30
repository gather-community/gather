class RenameCommunitiesConfigToSettings < ActiveRecord::Migration
  def change
    rename_column :communities, :config, :settings
  end
end
