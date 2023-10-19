# frozen_string_literal: true

class AddFullCmtysCanSendToGroupMailmanLists < ActiveRecord::Migration[7.0]
  def change
    add_column :group_mailman_lists, :full_cmtys_can_send, :boolean, null: false, default: false
  end
end
