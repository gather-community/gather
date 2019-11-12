# frozen_string_literal: true

class AddHouseholdForeignKey < ActiveRecord::Migration[4.2]
  def change
    add_foreign_key :households, :communities
  end
end
