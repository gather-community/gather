class AddCommunityToWikiPages < ActiveRecord::Migration
  def change
    add_reference :wiki_pages, :community, index: true, foreign_key: true, null: false
  end
end
