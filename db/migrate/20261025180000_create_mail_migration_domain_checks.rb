# frozen_string_literal: true

class CreateMailMigrationDomainChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :mail_migration_domain_checks do |t|
      t.references :cluster, null: false, foreign_key: true
      t.references :domain, null: false, foreign_key: true, index: {unique: true}
      t.jsonb :data, null: false, default: {}
      t.datetime :checked_at, null: false
      t.timestamps
    end
  end
end
