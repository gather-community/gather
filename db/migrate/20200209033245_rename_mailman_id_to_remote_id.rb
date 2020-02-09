# frozen_string_literal: true

class RenameMailmanIdToRemoteId < ActiveRecord::Migration[6.0]
  def change
    rename_column :group_mailman_users, :mailman_id, :remote_id
    rename_column :group_mailman_lists, :mailman_id, :remote_id
  end
end
