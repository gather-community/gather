class AddHomeToWikiPages < ActiveRecord::Migration
  def change
    add_column :wiki_pages, :home, :boolean, default: false, null: false
  end
end
