# frozen_string_literal: true

class SetGoogleEmailNullTrue < ActiveRecord::Migration[4.2]
  def change
    change_column_null :users, :google_email, true
  end
end
