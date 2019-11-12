# frozen_string_literal: true

class AddAlternateIdToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :alternate_id, :string
    add_index :users, :alternate_id
  end
end
