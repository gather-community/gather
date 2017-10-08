class AddClusterIdToWikiTables < ActiveRecord::Migration
  def change
    add_reference :wiki_pages, :cluster, index: true, foreign_key: true, null: false
    add_reference :wiki_page_versions, :cluster, index: true, foreign_key: true, null: false
  end
end
