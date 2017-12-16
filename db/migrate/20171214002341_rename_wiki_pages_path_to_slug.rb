class RenameWikiPagesPathToSlug < ActiveRecord::Migration
  def change
    rename_column :wiki_pages, :path, :slug
  end
end
