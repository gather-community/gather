# frozen_string_literal: true

class RenameWikiPagesPathToSlug < ActiveRecord::Migration[4.2]
  def change
    rename_column :wiki_pages, :path, :slug
  end
end
