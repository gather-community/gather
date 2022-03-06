# frozen_string_literal: true

class DisallowResetPasswordTokenWithoutFullAccess < ActiveRecord::Migration[6.0]
  def up
    ActsAsTenant.without_tenant do
      User.where(full_access: true).update_all(reset_password_token: nil)
    end
    add_check_constraint(:users, "(full_access = true OR reset_password_token IS NULL)",
                         name: :full_access_reset_password_token)
  end

  def down
    remove_check_constraint(:users, "(full_access = true OR reset_password_token IS NULL)",
                            name: :full_access_reset_password_token)
  end
end
