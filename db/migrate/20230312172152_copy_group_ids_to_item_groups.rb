# frozen_string_literal: true

class CopyGroupIdsToItemGroups < ActiveRecord::Migration[7.0]
  def up
    execute("
      INSERT INTO gdrive_item_groups(cluster_id, access_level,created_at,group_id,item_id,updated_at)
      SELECT cluster_id, 'reader', created_at, group_id, id, updated_at FROM gdrive_items
    ")
  end
end
