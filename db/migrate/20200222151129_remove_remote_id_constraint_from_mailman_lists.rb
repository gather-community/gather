# frozen_string_literal: true

class RemoveRemoteIdConstraintFromMailmanLists < ActiveRecord::Migration[6.0]
  def change
    change_column_null :group_mailman_lists, :remote_id, true
  end
end
