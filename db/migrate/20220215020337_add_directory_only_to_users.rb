# frozen_string_literal: true

class AddDirectoryOnlyToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :directory_only, :boolean, null: false, default: false
    ActsAsTenant.without_tenant do
      User.update_all("directory_only = child")
    end
  end
end
