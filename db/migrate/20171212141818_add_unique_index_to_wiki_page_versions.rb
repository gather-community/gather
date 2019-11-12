# frozen_string_literal: true

class AddUniqueIndexToWikiPageVersions < ActiveRecord::Migration[4.2]
  def change
    add_index :wiki_page_versions, %i[page_id number], unique: true
  end
end
