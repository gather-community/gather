# frozen_string_literal: true

class AddColsToGroup < ActiveRecord::Migration[6.0]
  def up
    add_column(:groups, :membership, :string, limit: 10, default: "closed", null: false)
    add_column(:groups, :slug, :string, limit: 32)
    ActsAsTenant.without_tenant do
      Groups::Group.all.each do |group|
        group.update_column(:slug, group.name.gsub(/(^[0-9]|[^A-za-z0-9])/, "").downcase)
      end
    end
    change_column_null(:groups, :slug, false)
  end

  def down
    remove_column(:groups, :membership)
    remove_column(:groups, :slug)
  end
end
