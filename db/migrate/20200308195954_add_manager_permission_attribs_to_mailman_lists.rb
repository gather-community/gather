# frozen_string_literal: true

class AddManagerPermissionAttribsToMailmanLists < ActiveRecord::Migration[6.0]
  def change
    add_column :group_mailman_lists, :managers_can_administer, :boolean, null: false, default: false
    add_column :group_mailman_lists, :managers_can_moderate, :boolean, null: false, default: false
  end
end
