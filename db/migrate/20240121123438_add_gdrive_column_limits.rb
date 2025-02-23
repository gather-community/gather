# frozen_string_literal: true

class AddGDriveColumnLimits < ActiveRecord::Migration[7.0]
  def up
    reversible do |dir|
      dir.up do
        change_column :gdrive_migration_folder_maps, :name, :text
        change_column :gdrive_migration_scan_tasks, :page_token, :string
      end
    end
    add_check_constraint :gdrive_migration_consent_requests, "char_length(opt_out_reason) <= 32767",
                         name: :opt_out_reason_length
    add_check_constraint :gdrive_migration_files, "char_length(name) <= 32767", name: :name_length
    add_check_constraint :gdrive_migration_folder_maps, "char_length(name) <= 32767", name: :name_length
  end
end
