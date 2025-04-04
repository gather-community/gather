# frozen_string_literal: true

class AddGoneStatusToGDriveMigrationFilesEnum < ActiveRecord::Migration[7.0]
  def change
    remove_check_constraint :gdrive_migration_files, "status::text = ANY (ARRAY['pending'::character varying, 'errored'::character varying, 'declined'::character varying, 'transferred'::character varying, 'copied'::character varying, 'ignored'::character varying]::text[])", name: "status_enum"
    add_check_constraint :gdrive_migration_files, "status::text = ANY (ARRAY['pending'::character varying, 'errored'::character varying, 'declined'::character varying, 'transferred'::character varying, 'copied'::character varying, 'ignored'::character varying, 'disappeared'::character varying]::text[])", name: "status_enum"
  end
end
