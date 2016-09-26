class AddCalendarTokenToUsers < ActiveRecord::Migration
  def change
    add_column :users, :calendar_token, :string
  end
end
