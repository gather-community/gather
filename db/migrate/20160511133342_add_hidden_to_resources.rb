# frozen_string_literal: true

class AddHiddenToResources < ActiveRecord::Migration[4.2]
  def change
    add_column :resources, :hidden, :boolean, null: false, default: false
  end
end
