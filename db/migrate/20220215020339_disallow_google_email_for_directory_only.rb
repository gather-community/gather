# frozen_string_literal: true

class DisallowGoogleEmailForDirectoryOnly < ActiveRecord::Migration[6.0]
  def up
    ActsAsTenant.without_tenant do
      User.where(directory_only: true).update_all(google_email: nil)
    end
    add_check_constraint(:users, "(directory_only = false OR google_email IS NULL)",
                         name: :directory_only_no_google_email)
  end

  def down
    remove_check_constraint(:users, "(directory_only = false OR google_email IS NULL)",
                            name: :directory_only_no_google_email)
  end
end
