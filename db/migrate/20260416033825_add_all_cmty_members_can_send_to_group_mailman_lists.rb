# frozen_string_literal: true

class AddAllCmtyMembersCanSendToGroupMailmanLists < ActiveRecord::Migration[7.0]
  def up
    if column_exists?(:group_mailman_lists, :all_cmty_members_can_send)
      change_column_default :group_mailman_lists, :all_cmty_members_can_send, from: true, to: false
    else
      add_column :group_mailman_lists, :all_cmty_members_can_send, :boolean, null: false, default: false
    end
  end

  def down
    if column_exists?(:group_mailman_lists, :all_cmty_members_can_send)
      change_column_default :group_mailman_lists, :all_cmty_members_can_send, from: false, to: true
    end
  end
end
