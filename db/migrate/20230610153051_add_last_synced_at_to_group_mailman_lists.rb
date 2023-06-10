# frozen_string_literal: true

class AddLastSyncedAtToGroupMailmanLists < ActiveRecord::Migration[7.0]
  def change
    add_column :group_mailman_lists, :last_synced_at, :datetime
  end
end
