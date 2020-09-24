# frozen_string_literal: true

class AddObituaryToMemorial < ActiveRecord::Migration[6.0]
  def change
    add_column :people_memorials, :obituary, :text
  end
end
