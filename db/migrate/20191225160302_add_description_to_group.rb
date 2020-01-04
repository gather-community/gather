# frozen_string_literal: true

class AddDescriptionToGroup < ActiveRecord::Migration[6.0]
  def up
    add_column :groups, :description, :string, limit: 255
  end
end
