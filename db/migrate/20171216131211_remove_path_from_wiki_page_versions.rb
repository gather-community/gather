class RemovePathFromWikiPageVersions < ActiveRecord::Migration
  def change
    remove_column :wiki_page_versions, :path, :string
  end
end
