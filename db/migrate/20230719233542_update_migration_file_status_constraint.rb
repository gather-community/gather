# frozen_string_literal: true

class UpdateMigrationFileStatusConstraint < ActiveRecord::Migration[7.0]
  def change
    remove_check_constraint :gdrive_migration_files,
                            "status::text = ANY (ARRAY['pending'::character varying, 'error'::character varying, 'declined'::character varying, 'done'::character varying]::text[])", name: "status_enum"
    execute("UPDATE gdrive_migration_files SET status = 'errored' WHERE status = 'error'")
    add_check_constraint :gdrive_migration_files,
                         "status::text = ANY (ARRAY['pending'::character varying, 'errored'::character varying, 'declined'::character varying, 'transferred'::character varying, 'copied'::character varying]::text[])", name: "status_enum"
  end
end
