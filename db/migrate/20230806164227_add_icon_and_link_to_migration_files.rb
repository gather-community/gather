# frozen_string_literal: true

class AddIconAndLinkToMigrationFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_files, :icon_link, :string
    add_column :gdrive_migration_files, :web_view_link, :string

    reversible do |dir|
      dir.up do
        execute("UPDATE gdrive_migration_files SET icon_link = 'https://drive-thirdparty.googleusercontent.com/32/type/application/pdf'")
        execute("UPDATE gdrive_migration_files SET web_view_link = 'https://drive.google.com/file/d/18nyjOaNbbzOWXhYRDXiiotJwwsYVvbE1/view'")
      end
    end

    change_column_null :gdrive_migration_files, :icon_link, false
    change_column_null :gdrive_migration_files, :web_view_link, false
  end
end
