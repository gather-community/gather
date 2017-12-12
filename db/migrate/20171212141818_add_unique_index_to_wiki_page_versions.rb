class AddUniqueIndexToWikiPageVersions < ActiveRecord::Migration
  def change
    add_index :wiki_page_versions, [:page_id, :number], unique: true
  end
end
