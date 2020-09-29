# frozen_string_literal: true

class AddUniqueIndexOnMemorialUser < ActiveRecord::Migration[6.0]
  def change
    remove_index :people_memorials, :user_id
    add_index :people_memorials, :user_id, unique: true
  end
end
