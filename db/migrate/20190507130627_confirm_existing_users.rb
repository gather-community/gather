# frozen_string_literal: true

class ConfirmExistingUsers < ActiveRecord::Migration[5.1]
  def up
    # Since we haven't had open signup to date, we're trusting all existing users, active or inactive.
    # But not fake ones.
    ActsAsTenant.without_tenant do
      User.where(fake: false).update_all(confirmed_at: Time.current)
    end
  end
end
