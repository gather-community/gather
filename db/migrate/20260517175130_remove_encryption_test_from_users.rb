# frozen_string_literal: true

class RemoveEncryptionTestFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :encryption_test, :text
  end
end
