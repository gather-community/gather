# frozen_string_literal: true

class RemoveNullConstraintOnWikiPages < ActiveRecord::Migration[5.1]
  def change
    change_column_null(:wiki_pages, :creator_id, true)
    change_column_null(:wiki_pages, :updator_id, true)
    change_column_null(:wiki_page_versions, :updator_id, true)
  end
end
