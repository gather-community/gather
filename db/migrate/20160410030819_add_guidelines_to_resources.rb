class AddGuidelinesToResources < ActiveRecord::Migration[4.2]
  def change
    add_column :resources, :guidelines, :text
  end
end
