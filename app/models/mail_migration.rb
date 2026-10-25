# frozen_string_literal: true

# Tracks the migration of custom mail domains to the new SMTP host.
module MailMigration
  def self.table_name_prefix
    "mail_migration_"
  end
end
