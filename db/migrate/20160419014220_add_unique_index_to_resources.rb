# frozen_string_literal: true

class AddUniqueIndexToResources < ActiveRecord::Migration[4.2]
  def change
    add_index :resources, %i[community_id name], unique: true
  end
end
