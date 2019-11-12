# frozen_string_literal: true

class AddDataSourceToWikiPages < ActiveRecord::Migration[5.1]
  def change
    add_column :wiki_pages, :data_source, :text
  end
end
