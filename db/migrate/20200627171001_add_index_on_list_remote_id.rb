# frozen_string_literal: true

class AddIndexOnListRemoteId < ActiveRecord::Migration[6.0]
  def change
    add_index(:group_mailman_lists, :remote_id, unique: true)
  end
end
