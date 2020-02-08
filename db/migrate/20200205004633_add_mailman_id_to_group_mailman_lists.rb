# frozen_string_literal: true

class AddMailmanIdToGroupMailmanLists < ActiveRecord::Migration[6.0]
  def change
    add_column :group_mailman_lists, :mailman_id, :string, null: false
  end
end
