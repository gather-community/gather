class AddGuidelinesToResources < ActiveRecord::Migration
  def change
    add_column :resources, :guidelines, :text
  end
end
