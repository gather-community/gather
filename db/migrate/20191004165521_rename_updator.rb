# frozen_string_literal: true

class RenameUpdator < ActiveRecord::Migration[5.1]
  def change
    rename_column :wiki_pages, :updator_id, :updater_id
    rename_column :wiki_page_versions, :updator_id, :updater_id
  end
end
