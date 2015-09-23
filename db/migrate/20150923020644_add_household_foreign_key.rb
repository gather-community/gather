class AddHouseholdForeignKey < ActiveRecord::Migration
  def change
    add_foreign_key :households, :communities
  end
end
