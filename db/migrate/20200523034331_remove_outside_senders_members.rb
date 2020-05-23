# frozen_string_literal: true

class RemoveOutsideSendersMembers < ActiveRecord::Migration[6.0]
  def change
    remove_column(:group_mailman_lists, :outside_members, :text)
    remove_column(:group_mailman_lists, :outside_senders, :text)
  end
end
