class AddRememberTokenToUsers < ActiveRecord::Migration
  def change
    add_column :users, :remember_token, :string
    ActsAsTenant.without_tenant do
      User.find_each do |user|
        user.update_attribute(:remember_token, Devise.friendly_token)
      end
    end
    change_column_null :users, :remember_token, false
  end
end
