# frozen_string_literal: true

class AddToGDriveMigrationFileErrorEnum < ActiveRecord::Migration[7.0]
  def change
    remove_check_constraint :gdrive_migration_files,
                            "error_type::text = ANY (ARRAY['forbidden'::character varying, 'not_found'::character varying]::text[])", name: "error_type_enum"
    add_check_constraint :gdrive_migration_files,
                         "error_type::text = ANY (ARRAY['forbidden'::character varying, 'not_found'::character varying, 'cant_edit'::character varying]::text[])", name: "error_type_enum"
  end
end
