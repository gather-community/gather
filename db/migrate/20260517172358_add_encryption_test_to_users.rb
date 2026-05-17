# frozen_string_literal: true

class AddEncryptionTestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :encryption_test, :text
  end
end
