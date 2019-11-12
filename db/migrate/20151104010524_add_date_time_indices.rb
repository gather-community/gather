# frozen_string_literal: true

class AddDateTimeIndices < ActiveRecord::Migration[4.2]
  def change
    add_index :statements, :created_at
  end
end
