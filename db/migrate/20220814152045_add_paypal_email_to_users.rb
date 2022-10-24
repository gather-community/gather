class AddPaypalEmailToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :paypal_email, :string, limit: 255
  end
end
