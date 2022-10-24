class AddLimitsOnEmailCols < ActiveRecord::Migration[6.0]
  def change
    change_column :people_emergency_contacts, :email, :string, limit: 255
    change_column :users, :email, :string, limit: 255
    change_column :users, :google_email, :string, limit: 255
    change_column :users, :unconfirmed_email, :string, limit: 255
  end
end
