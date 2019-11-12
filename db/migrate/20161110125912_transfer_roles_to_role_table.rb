# frozen_string_literal: true

class TransferRolesToRoleTable < ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      role_ids = {
        "admin" => insert("INSERT INTO roles (name, updated_at, created_at) VALUES ('admin', NOW(), NOW())"),
        "biller" => insert("INSERT INTO roles (name, updated_at, created_at) VALUES ('biller', NOW(), NOW())")
      }
      execute("SELECT id, admin, biller FROM users WHERE admin = 't' OR biller = 't'").to_a.each do |row|
        row.select { |_col, val| val == "t" }.each do |role, _val|
          insert("INSERT INTO users_roles (role_id, user_id) VALUES (#{role_ids[role]}, #{row['id']})")
        end
      end
    end
  end
end
