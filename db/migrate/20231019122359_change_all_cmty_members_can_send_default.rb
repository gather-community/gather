# frozen_string_literal: true

class ChangeAllCmtyMembersCanSendDefault < ActiveRecord::Migration[7.0]
  def change
    change_column_default :group_mailman_lists, :all_cmty_members_can_send, from: false, to: true
  end
end
