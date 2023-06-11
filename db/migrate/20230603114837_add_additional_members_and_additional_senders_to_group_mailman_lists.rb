# frozen_string_literal: true

class AddAdditionalMembersAndAdditionalSendersToGroupMailmanLists < ActiveRecord::Migration[7.0]
  def change
    add_column :group_mailman_lists, :additional_members, :jsonb
    add_column :group_mailman_lists, :additional_senders, :jsonb
  end
end
