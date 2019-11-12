# frozen_string_literal: true

class RemoveEmailIndex < ActiveRecord::Migration[4.2]
  def up
    remove_index :users, :email
  end
end
