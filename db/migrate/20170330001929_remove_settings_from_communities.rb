class RemoveSettingsFromCommunities < ActiveRecord::Migration
  def change
    remove_column :communities, :settings, :text
  end
end
