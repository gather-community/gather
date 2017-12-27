class RemovePathFromWikiPageVersions < ActiveRecord::Migration[4.2]
  def change
    remove_column :wiki_page_versions, :path, :string
  end
end
