class AddNotNullToWikiUpdator < ActiveRecord::Migration
  def change
    change_column_null :wiki_page_versions, :updator_id, false
  end
end
