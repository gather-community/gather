class RenameWikiHomeToSpecial < ActiveRecord::Migration[5.1]
  def change
    add_column :wiki_pages, :role, :string, index: true
    execute("UPDATE wiki_pages SET role = 'home' WHERE home = 't'")
    remove_column :wiki_pages, :home, :boolean
  end
end
