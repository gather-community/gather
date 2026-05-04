# frozen_string_literal: true

class AddArchivedAtToCommunities < ActiveRecord::Migration[8.1]
  def change
    add_column :communities, :archived_at, :datetime
    add_index :communities, :archived_at
  end
end
