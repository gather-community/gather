class FixWikiIndices < ActiveRecord::Migration
  def change
    add_index :wiki_pages, :updator_id
    remove_index :wiki_pages, :slug
    add_index :wiki_pages, [:community_id, :slug], unique: true
    add_index :wiki_pages, [:community_id, :title], unique: true
  end
end
