# frozen_string_literal: true

class AddCalendarTokenToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :calendar_token, :string
  end
end
