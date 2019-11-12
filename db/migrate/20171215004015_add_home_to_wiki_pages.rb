# frozen_string_literal: true

class AddHomeToWikiPages < ActiveRecord::Migration[4.2]
  def change
    add_column :wiki_pages, :home, :boolean, default: false, null: false
  end
end
