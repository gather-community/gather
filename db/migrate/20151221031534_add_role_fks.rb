# frozen_string_literal: true

class AddRoleFks < ActiveRecord::Migration[4.2]
  def up
    add_foreign_key :users_roles, :roles
    add_foreign_key :users_roles, :users
  end
end
