# frozen_string_literal: true

class AddFullAccessToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :full_access, :boolean, null: false, default: true
    ActsAsTenant.without_tenant do
      User.update_all("full_access = NOT(child)")
    end
  end
end
