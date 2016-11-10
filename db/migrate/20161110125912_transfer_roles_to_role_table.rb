class TransferRolesToRoleTable < ActiveRecord::Migration
  def up
    ActiveRecord::Base.transaction do
      role_ids = {
        "admin" => insert("INSERT INTO roles (name, updated_at, created_at) VALUES ('admin', NOW(), NOW())"),
        "biller" => insert("INSERT INTO roles (name, updated_at, created_at) VALUES ('biller', NOW(), NOW())")
      }
      execute("SELECT id, admin, biller FROM users WHERE admin = 't' OR biller = 't'").to_a.each do |row|
        row.select{ |col, val| val == "t" }.each do |role, val|
          insert("INSERT INTO users_roles (role_id, user_id) VALUES (#{role_ids[role]}, #{row['id']})")
        end
      end
    end
  end
end
