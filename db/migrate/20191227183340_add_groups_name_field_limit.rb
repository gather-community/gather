# frozen_string_literal: true

class AddGroupsNameFieldLimit < ActiveRecord::Migration[6.0]
  def change
    change_column :groups, :name, :string, limit: 64, null: false
  end
end
