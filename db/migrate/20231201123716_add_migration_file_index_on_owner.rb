# frozen_string_literal: true

class AddMigrationFileIndexOnOwner < ActiveRecord::Migration[7.0]
  def change
    add_index :gdrive_migration_files, %i[operation_id owner status],
              name: :index_gdrive_migration_files_on_owner
  end
end
