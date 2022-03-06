# frozen_string_literal: true

class DisallowGoogleEmailWithoutFullAccess < ActiveRecord::Migration[6.0]
  def up
    ActsAsTenant.without_tenant do
      User.where(full_access: false).update_all(google_email: nil)
    end
    add_check_constraint(:users, "(full_access = true OR google_email IS NULL)",
                         name: :full_access_no_google_email)
  end

  def down
    remove_check_constraint(:users, "(full_access = true OR google_email IS NULL)",
                            name: :full_access_no_google_email)
  end
end
