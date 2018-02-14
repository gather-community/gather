class AddEditableByToWikiPages < ActiveRecord::Migration[5.1]
  def change
    add_column :wiki_pages, :editable_by, :string, null: false, default: "everyone"
  end
end
