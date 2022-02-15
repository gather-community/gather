# frozen_string_literal: true

class DisallowResetPasswordTokenForDirectoryOnly < ActiveRecord::Migration[6.0]
  def up
    ActsAsTenant.without_tenant do
      User.where(directory_only: true).update_all(reset_password_token: nil)
    end
    add_check_constraint(:users, "(directory_only = false OR reset_password_token IS NULL)",
                         name: :directory_only_no_reset_password_token)
  end

  def down
    remove_check_constraint(:users, "(directory_only = false OR reset_password_token IS NULL)",
                            name: :directory_only_no_reset_password_token)
  end
end
