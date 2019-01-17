# frozen_string_literal: true

class RenameAssignmentRoleToOldRole < ActiveRecord::Migration[5.1]
  def change
    rename_column :assignments, :role, :old_role
  end
end
