# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_config, class: "GDrive::MigrationConfig" do
    community { Defaults.community }
    client_id { "236482765-xxx.apps.googleusercontent.com" }
    client_secret_to_write { "53VUKh3CKKWOgKY1yn4BaPfaDYpFXMwe222" }
  end
end
