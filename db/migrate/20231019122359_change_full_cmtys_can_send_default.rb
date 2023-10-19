# frozen_string_literal: true

class ChangeFullCmtysCanSendDefault < ActiveRecord::Migration[7.0]
  def change
    change_column_default :group_mailman_lists, :full_cmtys_can_send, from: false, to: true
  end
end
