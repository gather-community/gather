# frozen_string_literal: true

class AddCommunityToWikiPages < ActiveRecord::Migration[4.2]
  def change
    add_reference :wiki_pages, :community, index: true, foreign_key: true, null: false
  end
end
