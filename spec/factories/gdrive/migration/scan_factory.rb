# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_scan, class: "GDrive::Migration::Scan" do
    association :operation, factory: :gdrive_migration_operation
  end
end
