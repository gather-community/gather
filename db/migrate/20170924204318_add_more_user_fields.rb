# frozen_string_literal: true

class AddMoreUserFields < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :school, :string
    add_column :users, :allergies, :string
    add_column :users, :doctor, :string
    add_column :users, :medical, :text
  end
end
