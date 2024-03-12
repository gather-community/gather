# frozen_string_literal: true

class AddToMigrationFileErrors < ActiveRecord::Migration[7.0]
  def change
    remove_check_constraint :gdrive_migration_files, "error_type::text = ANY (ARRAY[
        'forbidden'::character varying,
        'not_found'::character varying,
        'ancestor_inaccessible'::character varying,
        'client_error_ensuring_tree'::character varying
      ]::text[])", name: "error_type_enum"
    add_check_constraint :gdrive_migration_files, "error_type::text = ANY (ARRAY[
        'forbidden'::character varying,
        'not_found'::character varying,
        'ancestor_inaccessible'::character varying,
        'client_error_ensuring_tree'::character varying,
        'client_error_moving_to_temp_drive'::character varying,
        'client_error_moving_to_destination'::character varying
      ]::text[])", name: "error_type_enum"
  end
end
