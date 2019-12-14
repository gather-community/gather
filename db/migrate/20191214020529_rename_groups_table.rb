# frozen_string_literal: true

class RenameGroupsTable < ActiveRecord::Migration[6.0]
  def change
    rename_table(:people_groups, :groups)
  end
end
