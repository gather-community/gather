# frozen_string_literal: true

class AddAllCmtyMembersCanSendToGroupMailmanLists < ActiveRecord::Migration[7.0]
  def change
    add_column :group_mailman_lists, :all_cmty_members_can_send, :boolean, null: false, default: false
  end
end
