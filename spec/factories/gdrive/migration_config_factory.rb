# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_config, class: "GDrive::MigrationConfig" do
    community { Defaults.community }
  end
end
