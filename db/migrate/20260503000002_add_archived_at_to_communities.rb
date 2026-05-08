# frozen_string_literal: true

class AddArchivedAtToCommunities < ActiveRecord::Migration[8.1]
  def change
    add_column :communities, :deactivated_at, :datetime
    add_index :communities, :deactivated_at
  end
end
