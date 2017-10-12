class AddWikiTableConstraints < ActiveRecord::Migration
  def change
    change_column_null :wiki_pages, :creator_id, false
    change_column_null :wiki_pages, :title, false
    change_column_null :wiki_page_versions, :number, false
    add_foreign_key :wiki_pages, :users, column: "creator_id"
    add_foreign_key :wiki_pages, :users, column: "updator_id"
    add_foreign_key :wiki_page_versions, :users, column: "updator_id"
    add_foreign_key :wiki_page_versions, :wiki_pages, column: "page_id"
  end
end
