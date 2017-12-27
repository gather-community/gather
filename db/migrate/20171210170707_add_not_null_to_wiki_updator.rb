class AddNotNullToWikiUpdator < ActiveRecord::Migration[4.2]
  def change
    change_column_null :wiki_page_versions, :updator_id, false
  end
end
