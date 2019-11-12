# frozen_string_literal: true

class RenameUserDeletedAt < ActiveRecord::Migration[4.2]
  def change
    rename_column :users, :deleted_at, :deactivated_at
  end
end
