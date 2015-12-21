class AddRoleFks < ActiveRecord::Migration
  def up
    add_foreign_key :users_roles, :roles
    add_foreign_key :users_roles, :users
  end
end
