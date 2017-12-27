class AddWikiNotNulls < ActiveRecord::Migration[4.2]
  def change
    change_column_null :wiki_pages, :created_at, false
    change_column_null :wiki_pages, :slug, false
    change_column_null :wiki_pages, :updated_at, false
    change_column_null :wiki_pages, :updator_id, false
    change_column_null :wiki_page_versions, :title, false
    change_column_null :wiki_page_versions, :updated_at, false
  end
end
